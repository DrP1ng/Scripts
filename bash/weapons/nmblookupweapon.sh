#!/bin/bash

# Comprobar si nmblookup está instalado
if ! command -v nmblookup &> /dev/null; then
    echo "[!] nmblookup no está instalado"
    exit 1
fi

# Comprobar la sintaxis de ejecución
if [ $# -ne 1 ]; then
    echo "[!] Incorrect syntax"
    echo "Usage: bash script.sh <file1>"
    exit 2
fi

# Comprobar si el fichero con IPs existe
file1=$1
if [ ! -f "$file1" ]; then
    echo "[!] El fichero $file1 no existe"
    exit 3
fi

# Comprobar si el usuario tiene permisos de lectura del fichero
if [ ! -r "$file1" ]; then
    echo "[!] Tu usuario no tiene permisos de lectura para $file1"
    exit 4
fi

# Comprobar que el fichero no está vacío y que el formato de las IPs es correcto
if [ ! -s "$file1" ]; then
    echo "[!] El fichero $file1 está vacío"
    exit 5
fi

ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
while read ip; do
    if [[ ! $ip =~ $ip_regex ]]; then
        echo "[!] El fichero $file1 contiene una IP con formato incorrecto: $ip"
        exit 6
    fi
done < "$file1"

# Contar las IPs que hay en el fichero y mostrar el número de IPs
num_ips=$(wc -l < "$file1")
echo "[*] El fichero $file1 contiene $num_ips IPs"

# Preguntar si quiero ejecutar el script
read -p "[?] Quieres ejecutar el script? (y/n): " answer
if [ "$answer" != "y" ]; then
    echo "[*] Saliendo del script"
    exit 7
fi

# Ejecutar el script para el usuario null con el siguiente formato: "nmblookup -A <IP>"
vulnerable_ips=()
recheck_ips=()
while read ip; do
    # Mostrar el mensaje "Checking hostname in <IP>..."
    echo "[*] Checking hostname in $ip..."

    # Ejecutar nmblookup y capturar el código de estado y la salida estándar y de error
    output=$(nmblookup -A "$ip" 2>&1)
    status=$?

    # Esperar 1 segundo hasta probar la siguiente dirección IP
    sleep 1

    # Comprobar el código de estado y la salida de nmblookup para determinar si la IP es vulnerable, no vulnerable o comprobable

    if [ $status -eq 0 ]; then # Se encontró al menos un nombre

        # Buscar en la salida si hay algún nombre con tipo 0x20 (Server)
        if grep -q "<20>" <<< "$output"; then
            # Se considera que la IP es vulnerable y se muestra en color rojo el mensaje "[!] <IP> Vulnerable!!"
            echo -e "\e[31m[!] $ip Vulnerable!!\e[0m"
            # Se añade la IP al array de IPs vulnerables
            vulnerable_ips+=("$ip")
        else
            # Se considera que la IP no es vulnerable y se muestra en color verde el mensaje "[!] <IP> No vulnerable!!"
            echo -e "\e[32m[!] $ip No vulnerable!!\e[0m"
        fi

    elif [ $status -eq 1 ]; then # No se encontró ningún nombre

        # Se considera que la IP no es vulnerable y se muestra en color verde el mensaje "[!] <IP> No vulnerable!!"
        echo -e "\e[32m[!] $ip No vulnerable!!\e[0m"

    else # Hubo algún error

        # Se considera que la IP es comprobable y se muestra en color amarillo el mensaje "[*] <IP> ReCheck!"
        echo -e "\e[33m[*] $ip ReCheck!\e[0m"
        # Se añade la IP al array de IPs comprobables
        recheck_ips+=("$ip")
    fi

done < "$file1"

# Mostrar "Done! <n> IPs tested" en rojo cuando termine de ejecutarse el fichero
echo -e "\e[31mDone! $num_ips IPs tested\e[0m"

# Si hay IPs que se consideran vulnerables, mostrar en color rojo el número de IPs vulnerables
num_vulnerable_ips=${#vulnerable_ips[@]}
if [ $num_vulnerable_ips -gt 0 ]; then
    echo -e "\e[31m[*] $num_vulnerable_ips IPs Vulnerable!!\e[0m"
fi

# Si hay IPs vulnerables, preguntar si quiere guardar las IPs vulnerables en un fichero en el directorio de trabajo actual
if [ $num_vulnerable_ips -gt 0 ]; then
    read -p "[?] Quieres guardar las IPs vulnerables en un fichero? (y/n): " answer
    if [ "$answer" == "y" ]; then
        # Pedir que elija un nombre para el fichero
        read -p "[?] Elige un nombre para el fichero: " file2
        # Guardar las IPs vulnerables en el fichero, ordenadas de menor a mayor y con una IP por fila
        printf "%s\n" "${vulnerable_ips[@]}" | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n > "$file2"
        # Mostrar el mensaje "[*] Vulnerable targets saved in <path>/<name>"
        path=$(pwd)
        echo "[*] Vulnerable targets saved in $path/$file2"
    fi
fi
