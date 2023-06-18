#!/bin/bash

# Comprobar si smbclient está instalado
if ! command -v smbclient &> /dev/null
then
    echo "[!] smbclient no está instalado"
    exit 1
fi

# Comprobar la sintaxis de ejecución
if [ $# -ne 1 ]
then
    echo "[!] Incorrect syntax"
    echo "Usage: bash script.sh <fichero1>"
    exit 2
fi

# Asignar el nombre del fichero a una variable
fichero=$1

# Comprobar si el fichero existe
if [ ! -f "$fichero" ]
then
    echo "[!] El fichero $fichero no existe"
    exit 3
fi

# Comprobar si el usuario tiene permisos de lectura del fichero
if [ ! -r "$fichero" ]
then
    echo "[!] Tu usuario no tiene permisos de lectura para $fichero"
    exit 4
fi

# Comprobar si el fichero está vacío
if [ ! -s "$fichero" ]
then
    echo "[!] El fichero $fichero está vacío"
    exit 5
fi

# Comprobar si el formato de las IPs es correcto
while read ip
do
    if ! [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    then
        echo "[!] El formato de la IP $ip es incorrecto"
        exit 6
    fi
done < "$fichero"

# Contar las IPs que hay en el fichero y mostrar el número de IPs
num_ips=$(wc -l < "$fichero")
echo "[*] Hay $num_ips IPs en el fichero"

# Preguntar si se quiere ejecutar el script
read -p "[?] Quieres ejecutar el script? (y/n): " respuesta

if [ "$respuesta" != "y" ] && [ "$respuesta" != "Y" ]
then
    echo "[*] Saliendo del script"
    exit 7
fi

# Ejecutar el script para el usuario null con el formato indicado

# Inicializar variables para contar las IPs vulnerables, no vulnerables y con error
vuln=0
no_vuln=0
error=0

# Recorrer las IPs del fichero y ejecutar smbclient para cada una
while read ip
do
    # Mostrar el mensaje de comprobación del usuario null
    echo "[*] Checking Null User for $ip..."

    # Ejecutar smbclient y capturar la salida y el código de retorno
    output=$(smbclient --no-pass -L "$ip" 2>&1)
    code=$?

    # Comprobar el código de retorno y la salida para clasificar la IP según su respuesta

    if [ $code -eq 0 ]
    then
        # Si el código es 0, se ha conseguido la autenticación y la IP es vulnerable

        # Mostrar la IP en color rojo usando códigos ANSI de escape (\e[31m para rojo y \e[0m para resetear)
        echo -e "\e[31m[+] $ip is vulnerable\e[0m"

        # Incrementar el contador de IPs vulnerables en uno
        ((vuln++))

        # Añadir la IP a un array de IPs vulnerables para guardarlas después si se desea
        vuln_ips+=("$ip")

    elif [ $code -eq 1 ] && [[ $output == *"NT_STATUS_ACCESS_DENIED"* || $output == *"NT_STATUS_LOGON_FAILURE"* ]]
    then
        # Si el código es 1 y la salida contiene NT_STATUS_ACCESS_DENIED o NT_STATUS_LOGON_FAILURE, se ha denegado la autenticación y la IP no es vulnerable

        # Mostrar la IP en color verde usando códigos ANSI de escape (\e[32m para verde y \e[0m para resetear)
        echo -e "\e[32m[-] $ip is not vulnerable\e[0m"

        # Incrementar el contador de IPs no vulnerables en uno
        ((no_vuln++))

    elif [ $code -eq 1 ] && [[ $output == *"NT_STATUS_NOT_SUPPORTED"* ]]
    then
        # Si el código es 1 y la salida contiene NT_STATUS_NOT_SUPPORTED, se ha producido un error y la IP no se puede comprobar

        # Mostrar la IP en color azul usando códigos ANSI de escape (\e[34m para azul y \e[0m para resetear)
        echo -e "\e[34m[!] $ip has an error\e[0m"

        # Incrementar el contador de IPs con error en uno
        ((error++))

    else
        # Si el código y la salida no coinciden con ninguno de los casos anteriores, se ha obtenido una respuesta diferente

        # Mostrar la IP en color amarillo usando códigos ANSI de escape (\e[33m para amarillo y \e[0m para resetear)
        echo -e "\e[33m[?] $ip has a different response\e[0m"

    fi

    # Esperar 1 segundo hasta probar la siguiente IP
    sleep 1

done < "$fichero"

# Mostrar el mensaje final en color rojo usando códigos ANSI de escape (\e[31m para rojo y \e[0m para resetear)
echo -e "\e[31mDone! $num_ips IPs tested\e[0m"

# Si hay IPs vulnerables, mostrar el número en color rojo usando códigos ANSI de escape (\e[31m para rojo y \e[0m para resetear)
if [ $vuln -gt 0 ]
then
    echo -e "\e[31mThere are $vuln vulnerable IPs\e[0m"
fi

# Si hay IPs vulnerables, preguntar si se quiere guardarlas en un fichero en el directorio actual
if [ $vuln -gt 0 ]
then
    read -p "[?] Do you want to save the vulnerable IPs in a file in the current directory? (y/n): " respuesta

    if [ "$respuesta" == "y" ] || [ "$respuesta" == "Y" ]
    then
        # Pedir que se elija un nombre para el fichero
        read -p "[?] Enter a name for the file: " nombre

        # Guardar las IPs vulnerables en el fichero ordenadas por orden numérico usando el comando sort
        printf "%s\n" "${vuln_ips[@]}" | sort -n > "$nombre"

        # Mostrar el mensaje de confirmación con la ruta y el nombre del fichero
        echo "[*] Vulnerable targets saved in $(pwd)/$nombre"
    fi
fi
