#!/bin/bash

# Comprobar si smbmap está instalado
if ! command -v smbmap &> /dev/null
then
    echo "[!] smbmap no está instalado"
    exit 1
fi

# Comprobar la sintaxis de ejecución
if [ $# -ne 1 ]
then
    echo "[!] Incorrect syntax"
    echo "Usage: bash script.sh <file1>"
    exit 2
fi

# Comprobar si el fichero con IPs existe
file1=$1
if [ ! -f "$file1" ]
then
    echo "[!] El fichero $file1 no existe"
    exit 3
fi

# Comprobar si el usuario tiene permisos de lectura del fichero
if [ ! -r "$file1" ]
then
    echo "[!] Tu usuario no tiene permisos de lectura para $file1"
    exit 4
fi

# Comprobar que el fichero no está vacío y que el formato de las IPs es correcto
if [ ! -s "$file1" ]
then
    echo "[!] El fichero $file1 está vacío"
    exit 5
fi

ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
while read ip; do
    if [[ ! $ip =~ $ip_regex ]]
    then
        echo "[!] El fichero $file1 contiene una IP con formato incorrecto: $ip"
        exit 6
    fi
done < "$file1"

# Contar las IPs que hay en el fichero y mostrar el número de IPs
num_ips=$(wc -l < "$file1")
echo "[*] Hay $num_ips IPs en el fichero $file1"

# Preguntar si quiero ejecutar el script
read -p "[?] Quieres ejecutar el script? (y/n) " answer
if [ "$answer" != "y" ]
then
    echo "[*] Saliendo del script"
    exit 7
fi

# Ejecutar el script para el usuario null y para el usuario qwerty con smbmap y mostrar los mensajes correspondientes

# Inicializar las variables para guardar las IPs vulnerables y su número
vuln_ips=()
num_vuln=0

# Recorrer las IPs del fichero con un bucle for
for ip in $(cat "$file1"); do

    # Ejecutar smbmap para el usuario null y guardar la salida en una variable
    echo "[*] Checking Null User..."
    output_null=$(smbmap -H "$ip")

    # Comprobar la salida y mostrar los mensajes en función del resultado

    if [[ $output_null == *"[+] User SMB session establishd on"* ]]
    then
        # IP vulnerable con usuario null, mostrar mensaje en rojo y añadir a la lista de vulnerables
        echo -e "\e[31m[!] Vulnerable!!\e[0m"
        vuln_ips+=("$ip")
        ((num_vuln++))

    elif [[ $output_null == *"[!] Authentication error"* ]]
    then
        # IP no vulnerable con usuario null, mostrar mensaje en verde y probar con usuario qwerty

        echo -e "\e[32m[+] No vulnerable!\e[0m"

        # Ejecutar smbmap para el usuario qwerty y guardar la salida en una variable
        echo "[*] Checking Qwerty User..."
        output_qwerty=$(smbmap -H "$ip" -u 'qwerty')

        # Comprobar la salida y mostrar los mensajes en función del resultado

        if [[ $output_qwerty == *"[+] User SMB session establishd on"* ]]
        then
            # IP vulnerable con usuario qwerty, mostrar mensaje en rojo y añadir a la lista de vulnerables
            echo -e "\e[31m[!] Vulnerable!!\e[0m"
            vuln_ips+=("$ip")
            ((num_vuln++))

        elif [[ $output_qwerty == *"[!] Authentication error"* ]]
        then
            # IP no vulnerable con usuario qwerty, mostrar mensaje en verde
            echo -e "\e[32m[+] No vulnerable!\e[0m"

        else
            # Respuesta diferente, mostrar mensaje en amarillo
            echo -e "\e[33m[*] ReCheck!\e[0m"
        fi

    elif [[ $output_null == *"[!] 445 not open on"* ]]
    then
        # IP no accesible, mostrar mensaje en azul
        echo -e "\e[34m[+] Host Unreachable!\e[0m"

    else
        # Respuesta diferente, mostrar mensaje en amarillo
        echo -e "\e[33m[*] ReCheck!\e[0m"
    fi

    # Esperar 1 segundo hasta probar la siguiente dirección IP
    sleep 1

done

# Mostrar "Done! <n> IPs tested" en rojo cuando termine de ejecutarse el fichero siendo <n> el número de veces que se ha ejecutado smbmap
echo -e "\e[31mDone! $num_ips IPs tested\e[0m"

# Si hay IPs que se consideran vulnerables, mostrar en color rojo el número de IPs vulnerables
if [ $num_vuln -gt 0 ]
then
    echo -e "\e[31mThere are $num_vuln vulnerable IPs\e[0m"
fi

# Si hay IPs vulnerables, preguntar si quiere guardar las IPs vulnerables en un fichero en el directorio de trabajo actual. Me pedirá que elija un nombre para el fichero y mostrará el mensaje "[*] Vulnerable targets saved in <path>/<name>" siendo <path> la ruta del directorio en el que se ha guardado el fichero y <name> el nombre que le he puesto al fichero. Las direcciones <IP> se guardarán por orden de menor a mayor, habiendo una dirección IP por fila
if [ $num_vuln -gt 0 ]
then
    read -p "[?] Quieres guardar las IPs vulnerables en un fichero? (y/n) " answer
    if [ "$answer" == "y" ]
    then
        read -p "[?] Elige un nombre para el fichero: " name
        path=$(pwd)
        # Ordenar las IPs de menor a mayor y guardarlas en el fichero
        printf "%s\n" "${vuln_ips[@]}" | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n > "$path/$name"
        echo "[*] Vulnerable targets saved in $path/$name"
    fi
fi
