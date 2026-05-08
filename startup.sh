#!/bin/bash

# $META and $HEADER are defined here to keep the curl commands below readable
META="http://metadata.google.internal/computeMetadata/v1/instance"
HEADER="Metadata-Flavor: Google"

# $NAME and $IP are fetched from GCP's metadata service — every GCP VM
# can query this internal endpoint to learn about itself at runtime
NAME=$(curl -H "$HEADER" "$META/name")
IP=$(curl -H "$HEADER" "$META/network-interfaces/0/ip")

# Use dnf (not apt) — CentOS is RHEL-based
dnf install -y httpd

# Write the HTML page to the default Apache web root
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<body>
  <h1>VM Metadata</h1>
  <h2>Instance Name: $NAME</h2>
  <h2>Internal IP: $IP</h2>
  <h2>Colombian prize included for free!</h2>
  <figure>
    <img src="https://test-1256099743.s3.us-east-2.amazonaws.com/Colombian/imgi_22_551283556_24677511425231259_7293143846320648055_n.jpg" alt="Colombian prize!" style="max-width:600px; width:100%; display:block; margin:1rem 0;">
    <figcaption>Colombian prize!</figcaption>
  </figure>
</body>
</html>
EOF

# Enable and start Apache — the --now flag starts it immediately
# 'enable' makes it persist across reboots
systemctl enable --now httpd
