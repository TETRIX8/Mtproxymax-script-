import subprocess
import re
from fastapi import FastAPI, HTTPException, Header
import uvicorn

app = FastAPI()

# Simple token for security
API_TOKEN = "MTProxyMaxSecretToken123"

def clean_ansi(text):
    # Remove ANSI escape sequences
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_escape.sub('', text)

def extract_link(text):
    # Find the Telegram proxy link in the output
    match = re.search(r'(https://t.me/proxy\?server=[^\s]+)', text)
    if match:
        return match.group(1)
    return None

def run_command(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            return {"error": clean_ansi(result.stderr.strip())}
        
        raw_output = clean_ansi(result.stdout)
        link = extract_link(raw_output)
        
        if link:
            return {"link": link}
        return {"output": raw_output.strip()}
    except Exception as e:
        return {"error": str(e)}

@app.get("/get-test")
async def get_test(authorization: str = Header(None)):
    if authorization != f"Bearer {API_TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    res = run_command("mtproxymax-pool get-test")
    if "error" in res:
        raise HTTPException(status_code=500, detail=res["error"])
    return res

@app.get("/get-regular")
async def get_regular(label: str, period: str = "", authorization: str = Header(None)):
    if authorization != f"Bearer {API_TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    if not label:
        raise HTTPException(status_code=400, detail="Label is required")
    
    res = run_command(f"mtproxymax-pool get-regular {label} '{period}'")
    if "error" in res:
        raise HTTPException(status_code=500, detail=res["error"])
    return res

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
