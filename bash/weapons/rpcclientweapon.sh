# NO FUNCIONA BIEN. CUANDO ENCUENTRA UN POSITIVO SE PARA
# UPDATE: MOSTRAR POR PANTALLA LOS RESULTADOS DE RECHECK

#!/bin/bash

# Comprobar si rpcclient está instalado
if ! command -v rpcclient &> /dev/null
then
    echo "[!] rpcclient no está instalado"
    exit 1
fi

# Comprobar la sintaxis de ejecución
if [ $# -ne 1 ]
then
    echo "[!] Incorrect syntax"
    echo "Usage: bash script.sh <fichero1>"
    exit 2
fi

# Comprobar si el fichero con IPs existe
fichero=$1
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

# Comprobar que el fichero no está vacío y que el formato de las IPs es correcto
if [ ! -s "$fichero" ]
then
    echo "[!] El fichero $fichero está vacío"
    exit 5
fi

ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
while read ip
do
    if [[ ! $ip =~ $ip_regex ]]
    then
        echo "[!] El fichero $fichero contiene una IP con formato incorrecto: $ip"
        exit 6
    fi
done < "$fichero"

# Contar las IPs que hay en el fichero y mostrar el número de IPs
num_ips=$(wc -l < "$fichero")
echo "El fichero $fichero contiene $num_ips IPs"

# Preguntar si quiero ejecutar el script
read -p "¿Quieres ejecutar el script? (y/n): " answer
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]
then
    echo "Saliendo del script..."
    exit 7
fi

# Ejecutar el script con el siguiente formato: "rpcclient -U "" -N <IP>" siendo <IP>, la dirección IP a comprobar

# Inicializar variables para contar vulnerables y comprobables
vulnerables=0
comprobables=0

# Recorrer las IPs del fichero y ejecutar rpcclient para cada una de ellas
while read ip
do
    # Mostrar el mensaje "Checking Null User in <IP>" mientras se ejecuta el script siendo <IP> la dirección IP a comprobar
    echo "Checking Null User in $ip"

    # Ejecutar rpcclient y guardar la salida en una variable llamada output
    output=$(rpcclient -U "" -N "$ip")

    # Comprobar la salida de rpcclient y mostrar el mensaje correspondiente según el caso

    # Si se ha obtenido la respuesta "NT_STATUS_OK" o "NT_STATUS_IS_OK" se considerará que esa dirección IP es vulnerable. Se mostrará en color rojo el mensaje "[!] Vulnerable!!"
    if [[ $output == *"NT_STATUS_OK"* ]] || [[ $output == *"NT_STATUS_IS_OK"* ]]
    then
        echo -e "\e[31m[!] Vulnerable!!\e[0m"
        # Incrementar el contador de vulnerables en uno
        ((vulnerables++))
        # Cerrar la sesión de rpcclient y continuar con la siguiente IP
        rpcclient -c quit "$ip"
        continue

    # Si se ha obtenido la respuesta "NT_STATUS_ACCESS_DENIED" se considerará que esa dirección IP es no vulnerable. Se mostrará en color verde el mensaje "[+] No vulnerable!"
    elif [[ $output == *"NT_STATUS_ACCESS_DENIED"* ]]
    then
        echo -e "\e[32m[+] No vulnerable!\e[0m"

    # Si se ha obtenido la respuesta "STATUS_LOGON_FAILURE" se considerará que esa dirección IP es no autenticable. Se mostrará en color amarillo el mensaje "[+] Logon Failure. ReCheck!"
    elif [[ $output == *"STATUS_LOGON_FAILURE"* ]]
    then
        echo -e "\e[33m[+] Logon Failure. ReCheck!\e[0m"

    # Si se ha obtenido la respuesta "STATUS_SUCCESS" se considerará que esa dirección IP es interesante. Se mostrará en color amarillo el mensaje "[+] Logon Failure. ReCheck!"
    elif [[ $output == *"STATUS_SUCCESS"* ]]
    then
        echo -e "\e[33m[+] Logon Failure. ReCheck!\e[0m"

    # Si se ha obtenido la respuesta "NT_STATUS_NOT_SUPPORTED" o la respuesta "NT_STATUS_TO_TIMEOUT" se considerará que esa dirección IP genera un error. Se mostrará en color azul el mensaje "[-] Error!"
    elif [[ $output == *"NT_STATUS_NOT_SUPPORTED"* ]] || [[ $output == *"NT_STATUS_TO_TIMEOUT"* ]]
    then
        echo -e "\e[34m[-] Error!\e[0m"

    # Si se ha obtenido la respuesta "NT_STATUS_HOST_UNREACHABLE" se considerará que esa IP es inalcanzable. Se mostrará en color azul el mensaje "[-] Unreachable!"
    elif [[ $output == *"NT_STATUS_HOST_UNREACHABLE"* ]]
    then
        echo -e "\e[34m[-] Unreachable!\e[0m"

    # Si se ha obtenido una respuesta diferente a todas las anteriores se considerará que esa dirección IP es comprobable. Se mostrará en color naranja el mensaje "[+] Unknow Status. ReCheck!"
    else
        echo -e "\e[35m[+] Unknow Status. ReCheck!\e[0m"
        # Incrementar el contador de comprobables en uno
        ((comprobables++))
    fi

    # Esperar 1 segundo hasta probar la siguiente dirección IP
    sleep 1

done < "$fichero"

# Mostrar "Done! <n> IPs tested" en rojo cuando termine de ejecutarse el script siendo <n> el número real de veces que se ha ejecutado rpcclient
echo -e "\e[31mDone! $num_ips IPs tested\e[0m"

# Si hay IPs que se consideran vulnerables, mostrar en color rojo el número de IPs vulnerables
if [ $vulnerables -gt 0 ]
then
    echo -e "\e[31m$vulnerables IPs are vulnerable\e[0m"
fi

# Si hay IPs vulnerables, preguntar si quiere guardar las IPs vulnerables en un fichero en el directorio de trabajo actual
if [ $vulnerables -gt 0 ]
then
    read -p "¿Quieres guardar las IPs vulnerables? (y/n): " answer
    if [ "$answer" == "y" ] || [ "$answer" == "Y" ]
    then
        # Crear un fichero llamado vulnerables.txt y escribir las IPs vulnerables en él
        touch vulnerables.txt
        while read ip
        do
            output=$(rpcclient -U "" -N "$ip")
            if [[ $output == *"NT_STATUS_OK"* ]] || [[ $output == *"NT_STATUS_IS_OK"* ]]
            then
                echo "$ip" >> vulnerables.txt
            fi
        done < "$fichero"
        # Mostrar el mensaje "Las IPs vulnerables se han guardado en el fichero vulnerables.txt"
        echo "Las IPs vulnerables se han guardado en el fichero vulnerables.txt"
    fi
fi

# Fin del script
