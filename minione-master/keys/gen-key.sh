#!/bin/bash

KEYFILE=$1

if [ -z "$KEYFILE" ]; then
   KEYFILE="key"
   echo
   echo "Se ha creado key y key.pub"
   echo "Para definir el nombre de la key ejecutar"
   echo
   echo "$0 <nombre_de_la_key>"
   echo
else
   echo
   echo "Se crearan los archivos '$KEYFILE' para la llave privada y"
   echo "'$KEYFILE.pub' para la llave publica"
   echo
fi

ssh-keygen -t ed25519 -q -f $KEYFILE -N "" -C "noname"

