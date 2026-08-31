#!/bin/bash
# Descarga el archivo de Google Drive
echo "Descargando cofre desde Google Drive..."
curl -L -o /tmp/compartido_drive.json "https://drive.google.com/uc?export=download&id=1728stc7O7fLAZ_N6FWBKsCvkapYIc1Hp"

# Importa el contenido a la base de datos local
echo "Importando a la base de datos local..."
python3 $(dirname "$0")/sync.py bajar /tmp/compartido_drive.json

# Exporta el conocimiento unificado
echo "Exportando base de datos actualizada..."
python3 $(dirname "$0")/sync.py subir

echo "¡Sincronización completada!"
