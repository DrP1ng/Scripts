#!/bin/bash

# Comprobar si crackmapexec está instalado
if ! command -v crackmapexec &> /dev/null
then
    echo "[!] crackmapexec no está instalado"
    exit 1
fi

# Comprobar la sintaxis de ejecución
if [ $# -ne 1 ]
then
    echo "[!] Incorrect syntax"
    echo "Usage: bash script.sh <file1>"
    exit 2
fi

# Asignar el nombre del fichero a una variable
file=$1

# Comprobar si el fichero existe
if [ ! -f "$file" ]
then
    echo "[!] El fichero $file no existe"
    exit 3
fi

# Comprobar si el usuario tiene permisos de lectura del fichero
if [ ! -r "$file" ]
then
    echo "[!] Tu usuario no tiene permisos de lectura para $file"
    exit 4
fi

# Comprobar que el fichero no está vacío y que el formato de las IPs es correcto
if [ ! -s "$file" ]
then
    echo "[!] El fichero $file está vacío"
    exit 5
fi

# Usar una expresión regular para validar las IPs
regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"

# Leer el fichero línea por línea y comprobar cada IP
while read line; do
    if [[ ! $line =~ $regex ]]
    then
        echo "[!] El fichero $file contiene un formato de IP incorrecto: $line"
        exit 6
    fi
done < "$file"

# Contar las IPs que hay en el fichero y mostrar el número de IPs
count=$(wc -l < "$file")
echo "[*] Hay $count IPs en el fichero $file"

# Preguntar si quiere ejecutar el script
read -p "[?] Quieres ejecutar el script? (y/n): " answer

# Si la respuesta es afirmativa, ejecutar el script
if [ "$answer" == "y" ] || [ "$answer" == "Y" ]
then

    # Crear un array vacío para guardar las IPs vulnerables
    vulnerable=()

    # Leer el fichero línea por línea y ejecutar crackmapexec con cada IP
    while read ip; do

        # Mostrar el mensaje de comprobación de firma para cada IP
        echo "[*] Checking signature for $ip"

        # Ejecutar crackmapexec con la opción --no-bruteforce para evitar ataques de fuerza bruta y guardar la salida en una variable
        output=$(crackmapexec smb $ip --no-bruteforce)

        # Comprobar la salida y mostrar el mensaje correspondiente según el valor de signing
        if [[ $output == *"signing:True"* ]]
        then
            # Añadir la IP al array de vulnerables y mostrar el mensaje en rojo
            vulnerable+=($ip)
            echo -e "\e[31m[!] $ip Vulnerable!!\e[0m"
        elif [[ $output == *"signing:False"* ]]
        then
            # Mostrar el mensaje en verde
            echo -e "\e[32m[+] $ip No vulnerable!!\e[0m"
        else
            # Mostrar el mensaje en amarillo
            echo -e "\e[33m[*] $ip ReCheck!\e[0m"
        fi

        # Esperar 1 segundo hasta probar la siguiente IP
        sleep 1

    done < "$file"

    # Mostrar el mensaje final en rojo con el número de IPs testeadas
    echo -e "\e[31mDone! $count IPs tested\e[0m"

    # Si hay IPs vulnerables, mostrar el número en rojo y preguntar si quiere guardarlas en un fichero
    if [ ${#vulnerable[@]} -gt 0 ]
    then
        echo -e "\e[31m[*] Hay ${#vulnerable[@]} IPs vulnerables\e[0m"
        read -p "[?] Quieres guardar las IPs vulnerables en un fichero? (y/n): " save

        # Si la respuesta es afirmativa, pedir un nombre para el fichero y guardarlo en el directorio actual
        if [ "$save" == "y" ] || [ "$save" == "Y" ]
        then
            read -p "[?] Elige un nombre para el fichero: " filename
            # Ordenar las IPs de menor a mayor y guardar una por línea en el fichero
            printf "%s\n" "${vulnerable[@]}" | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n > "$filename"
            # Obtener la ruta del directorio actual
            path=$(pwd)
            # Mostrar el mensaje de confirmación con la ruta y el nombre del fichero
            echo "[*] Vulnerable targets saved in $path/$filename"
        fi
    fi

# Si la respuesta es negativa, salir del script
else
    echo "[*] Saliendo del script"
    exit 0
fi
