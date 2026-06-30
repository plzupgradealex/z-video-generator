import os
from zai import ZaiClient

# NEVER hardcode the key. Read it from the environment.
# The key previously committed here was rotated and removed — if you still have
# it anywhere, rotate it at z.ai. Set the env var before running:
#   export ZAI_API_KEY=...
_api_key = os.environ.get("ZAI_API_KEY")
if not _api_key:
    raise SystemExit("Set ZAI_API_KEY first (e.g. export ZAI_API_KEY=...).")
client = ZaiClient(api_key=_api_key)

# Generate video
response = client.videos.generations(
    model="cogvideox-3",
    prompt="A male Chinese university volleyball team actively training on a sandy beach court, players wearing tight fitted athletic compression shirts and shorts, diving for balls, jumping to spike, sweating, dynamic sports action, realistic cinematography",
    quality="quality",  # Output mode, "quality" for quality priority, "speed" for speed priority
    with_audio=True, # Whether to include audio
    size="1920x1080",  # Video resolution, supports up to 4K (e.g., "3840x2160")
    fps=30,  # Frame rate, can be 30 or 60
    duration=10,  # Video duration in seconds: 5 or 10
)
print(response)

# Poll until the video is ready
import time
while True:
    result = client.videos.retrieve_videos_result(id=response.id)
    print(f"Status: {result.task_status}")
    if result.task_status == 'SUCCESS':
        print(f"Video URL: {result.video_result}")
        break
    elif result.task_status == 'FAIL':
        print("Video generation failed!")
        break
    time.sleep(10)