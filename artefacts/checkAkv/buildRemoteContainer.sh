#!/bin/bash


echo "Started building image $2 on registry $1"
echo "Download artefacts..."
wget https://raw.githubusercontent.com/mocelj/AzureBatch-Secured/main/artefacts/checkAkv/checkAkv.tgz   
echo "Extracting artefacts..."
tar xvzf checkAkv.tgz
echo "Building image $2 on registry $1"
fullImage="$2:latest"
az acr build --registry $1 --image $fullImage .  
echo 'Build finished'