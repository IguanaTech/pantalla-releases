# PantallaPremios — releases

Paquetes y manifiesto de actualización de la pantalla de premios. El código fuente es privado.

## Instalar

Con la cuenta que va a mostrar la pantalla, sin `sudo`:

```bash
wget https://raw.githubusercontent.com/IguanaTech/pantalla-releases/main/instalar-pantalla.sh
bash instalar-pantalla.sh                  # o: bash instalar-pantalla.sh --sin-arranque
```

O en una línea:

```bash
curl -fsSL https://raw.githubusercontent.com/IguanaTech/pantalla-releases/main/instalar-pantalla.sh | bash
```

Instala la última versión publicada: verifica la firma del manifiesto y el sha256 del paquete
antes de instalar. También está en cada release
(`releases/latest/download/instalar-pantalla.sh`).
