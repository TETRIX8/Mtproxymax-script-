
#!/bin/bash

# Проверка, запущен ли скрипт от root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт от имени root пользователя (sudo -i)"
  exit 1
fi

# Обновление системы и установка зависимостей
echo "Обновление системы и установка необходимых пакетов..."
apt-get update -y
apt-get install -y python3 python3-pip git curl

# Клонирование репозитория MTProxy
echo "Клонирование репозитория MTProxy..."
if [ -d "/root/mtprotoproxy" ]; then
    echo "Директория /root/mtprotoproxy уже существует. Обновление..."
    cd /root/mtprotoproxy && git pull
else
    git clone -b stable https://github.com/alexbers/mtprotoproxy.git /root/mtprotoproxy
fi

# Конфигурация MTProxy (установка порта 5443)
echo "Настройка MTProxy: установка порта 5443..."
sed -i 's/PORT = 443/PORT = 5443/' /root/mtprotoproxy/config.py

# Установка зависимостей FastAPI
echo "Установка зависимостей FastAPI..."
pip3 install fastapi uvicorn pydantic

# Создание директории для FastAPI приложения
echo "Создание директории для FastAPI приложения..."
mkdir -p /root/mtproxy_api

# Запись кода FastAPI main.py
echo "Запись кода FastAPI main.py..."
cat <<EOF > /root/mtproxy_api/main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import re
import secrets
import subprocess
import time

app = FastAPI()

CONFIG_PATH = "/root/mtprotoproxy/config.py"

class User(BaseModel):
    name: str
    secret: str = None

def read_config():
    if not os.path.exists(CONFIG_PATH):
        return {}
    with open(CONFIG_PATH, "r") as f:
        content = f.read()
    users_match = re.search(r"USERS = ({.*?})", content, re.DOTALL)
    if users_match:
        users_str = users_match.group(1)
        # Safely evaluate the dictionary string
        users_dict = eval(users_str)
        return users_dict
    return {}

def write_config(users_dict):
    with open(CONFIG_PATH, "r") as f:
        content = f.read()
    
    users_str = "{\n" + ",\n".join([f"    \"{name}\": \"{secret}\"" for name, secret in users_dict.items()]) + "\n}"
    
    new_content = re.sub(r"USERS = {.*?}", f"USERS = {users_str}", content, flags=re.DOTALL)
    with open(CONFIG_PATH, "w") as f:
        f.write(new_content)
    
    # Restart MTProxy to apply changes
    restart_mtproxy()

def restart_mtproxy():
    # Find and kill existing mtprotoproxy process
    try:
        # Using shell to find and kill the process
        subprocess.run("sudo pkill -f mtprotoproxy.py", shell=True, check=False)
        time.sleep(1) # Wait for the process to terminate
        # Start mtprotoproxy again
        subprocess.Popen("sudo nohup python3 /root/mtprotoproxy/mtprotoproxy.py > /tmp/mtproxy.log 2>&1 &", 
                         shell=True,
                         cwd="/root/mtprotoproxy")
    except Exception as e:
        print(f"Error restarting MTProxy: {e}")

@app.get("/users")
async def get_users():
    users = read_config()
    return {"users": users}

@app.post("/users")
async def add_user(user: User):
    users = read_config()
    if user.name in users:
        raise HTTPException(status_code=400, detail="User already exists")
    
    if not user.secret:
        user.secret = secrets.token_hex(16)

    users[user.name] = user.secret
    write_config(users)
    return {"message": "User added successfully", "user": user}

@app.delete("/users/{name}")
async def delete_user(name: str):
    users = read_config()
    if name not in users:
        raise HTTPException(status_code=404, detail="User not found")
    del users[name]
    write_config(users)
    return {"message": "User deleted successfully"}

@app.put("/users/{name}")
async def update_user(name: str, user: User):
    users = read_config()
    if name not in users:
        raise HTTPException(status_code=404, detail="User not found")
    
    if not user.secret:
        user.secret = secrets.token_hex(16)

    users[name] = user.secret
    write_config(users)
    return {"message": "User updated successfully", "user": user}
EOF

# Запуск MTProxy
echo "Запуск MTProxy..."
pkill -f mtprotoproxy.py
cd /root/mtprotoproxy && sudo nohup python3 mtprotoproxy.py > /tmp/mtproxy.log 2>&1 &

# Запуск FastAPI API
echo "Запуск FastAPI API..."
pkill -f uvicorn
cd /root/mtproxy_api && nohup uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/fastapi.log 2>&1 &

echo "Установка завершена!"
echo "MTProxy запущен на порту 5443."
echo "FastAPI API запущен на порту 8000."
echo "Вы можете получить доступ к API по адресу: http://<ВАШ_IP>:8000"
