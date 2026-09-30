import asyncio
import uuid
import websockets
import json
import httpx
import time

async def test_live_call():
    health_url = "https://vanirakshak-backend-docker.onrender.com/v1/health"
    print(f"Waiting for backend to be ready at {health_url}...")
    
    for _ in range(60): # wait up to 10 minutes (60 * 10)
        try:
            async with httpx.AsyncClient() as client:
                r = await client.get(health_url, timeout=10.0)
                if r.status_code == 200:
                    print(f"Backend is UP! Health: {r.json()}")
                    break
        except Exception as e:
            pass
        print("Backend not ready yet, waiting 10s...")
        await asyncio.sleep(10)
    else:
        print("Backend failed to come up in time.")
        return

    session_id = str(uuid.uuid4())
    url = f"wss://vanirakshak-backend-docker.onrender.com/ws/session/{session_id}"
    print(f"Connecting to {url}...")
    try:
        async with websockets.connect(url) as ws:
            print("Connected! Waiting for backend to initialize session...")
            response = await ws.recv()
            print("Received:", response)
            
            print("Sending dummy audio frame (simulated silent PCM)...")
            # Send a tiny silent PCM chunk
            dummy_pcm = b'\x00' * 3200
            await ws.send(dummy_pcm)
            
            print("Waiting for risk update...")
            # Wait for risk_update
            response2 = await ws.recv()
            print("Received:", response2)
            
            print("Sending EOS...")
            await ws.send("EOS")
            
            print("Waiting for final result...")
            response3 = await ws.recv()
            print("Received final:", response3)
            
            print("\nTEST PASSED! Backend is healthy and processing audio.")
    except Exception as e:
        print(f"TEST FAILED: {e}")

if __name__ == "__main__":
    asyncio.run(test_live_call())
