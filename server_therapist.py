# therapist_server.py
import socket

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.bind(('0.0.0.0', 4040))
server.listen(1)
print("Waiting for client...")

client, addr = server.accept()
print("Connected to", addr)

while True:
    data = client.recv(1024)
    if not data:
        break
    print("Client says:", data.decode())
    client.sendall(b"Thank you for sharing. I'm here for you.")
