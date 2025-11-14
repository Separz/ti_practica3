#!/bin/bash

host=172.16.25.2

ssh-keygen -f "$HOME/.ssh/known_hosts" -R $host
ssh -o StrictHostKeyChecking=no $host 'echo Reset SSH NODO1 exitoso'
