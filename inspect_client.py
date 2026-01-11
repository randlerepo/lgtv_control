from aiowebostv import WebOsClient
import inspect

print("Init signature:", inspect.signature(WebOsClient.__init__))
print("Connect signature:", inspect.signature(WebOsClient.connect))
