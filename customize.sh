##########################################################################################
#
# Magisk Module Installer Script
#
##########################################################################################

# skip all default installation steps
SKIPUNZIP=0

# Set what you want to display when installing your module

print_modname() {
  ui_print " "
  ui_print "*******************************"
  ui_print " Supports Android7-15 move cert"
  ui_print "*******************************"
  ui_print " "
}

# Copy/extract your module files into $MODDIR in on_install.

on_install() {
  D_CERTIFICATE="$MODPATH/certificates"
  INSTALLED_LIST="$MODPATH/installed.list"

  mkdir -p -m 755 "$D_CERTIFICATE"

  # 初始化 installed.list，记录模块内置证书
  > "$INSTALLED_LIST"
  if [ -d "$D_CERTIFICATE" ] && [ "$(ls -A $D_CERTIFICATE 2>/dev/null)" ]; then
    ui_print "- Found bundled certificates"
    for cert in "$D_CERTIFICATE"/*.0; do
      [ -f "$cert" ] || continue
      hash=$(basename "$cert" .0)
      echo "${hash}:builtin" >> "$INSTALLED_LIST"
      ui_print "  - $hash (builtin)"
    done
  fi
  
  # 如果有待安装的 pem/crt/cer 文件，也记录（会在 post-fs-data 时转换）
  for cert in "$D_CERTIFICATE"/*.pem "$D_CERTIFICATE"/*.crt "$D_CERTIFICATE"/*.cer; do
    [ -f "$cert" ] || continue
    ui_print "  - $(basename "$cert") (will convert on boot)"
  done
  
  ui_print "- Certificates will be installed on next boot"
}

# You can add more functions to assist your custom script code
print_modname
on_install
