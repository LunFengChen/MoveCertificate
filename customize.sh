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
  D_TMP_CERT=/data/local/tmp/cert
  D_USER_CERT=/data/misc/user/0/cacerts-added

  mkdir -p -m 777 "$D_TMP_CERT"
  mkdir -p -m 755 "$D_CERTIFICATE"
  mkdir -p -m 755 "$D_USER_CERT"

  # 如果模块打包了证书，复制到待安装目录
  if [ -d "$MODPATH/certificates" ] && [ "$(ls -A $MODPATH/certificates 2>/dev/null)" ]; then
    ui_print "- Found bundled certificates"
    cp -f "$MODPATH/certificates"/* "$D_TMP_CERT/" 2>/dev/null
    ui_print "- Certificates will be installed on next boot"
  fi
}

# You can add more functions to assist your custom script code
print_modname
on_install
