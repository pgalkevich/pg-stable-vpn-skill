#!/bin/sh
set -eu

src=${1:-/tmp/amneziawg-home.conf}
settings=/jffs/addons/custom_settings.txt
tmp_settings=/tmp/awg-custom-settings.$$
tmp_parsed=/tmp/awg-parsed.$$
tmp_init=/tmp/awg-init.$$

cleanup() {
    rm -f "$tmp_settings" "$tmp_parsed" "$tmp_init"
}
trap cleanup EXIT INT TERM

[ -f "$src" ] || { echo "Config not found: $src" >&2; exit 1; }
touch "$settings"
chmod 600 "$settings"

awk '
function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
/^[[:space:]]*\[Interface\][[:space:]]*$/ { section="interface"; next }
/^[[:space:]]*\[Peer\][[:space:]]*$/ { section="peer"; next }
/^[[:space:]]*(#|$)/ { next }
{
    pos=index($0, "="); if (!pos) next
    key=trim(substr($0,1,pos-1)); value=trim(substr($0,pos+1))
    out=""
    if (section=="interface") {
        if (key=="PrivateKey") out="awg_privatekey"
        else if (key=="Address") out="awg_address"
        else if (key=="ListenPort") out="awg_listenport"
        else if (key=="DNS") out="awg_dns"
        else if (key=="Jc") out="awg_jc"
        else if (key=="Jmin") out="awg_jmin"
        else if (key=="Jmax") out="awg_jmax"
        else if (key=="S1") out="awg_s1"
        else if (key=="S2") out="awg_s2"
        else if (key=="S3") out="awg_s3"
        else if (key=="S4") out="awg_s4"
        else if (key=="H1") out="awg_h1"
        else if (key=="H2") out="awg_h2"
        else if (key=="H3") out="awg_h3"
        else if (key=="H4") out="awg_h4"
        else if (key ~ /^I[1-5]$/) { print key " = " value > initfile; next }
    } else if (section=="peer") {
        if (key=="PublicKey") out="awg_peer_pubkey"
        else if (key=="PresharedKey") out="awg_peer_psk"
        else if (key=="Endpoint") out="awg_peer_endpoint"
        else if (key=="AllowedIPs") out="awg_peer_allowedips"
        else if (key=="PersistentKeepalive") out="awg_peer_keepalive"
    }
    if (out!="") print out "\t" value
}
' initfile="$tmp_init" "$src" > "$tmp_parsed"

keys=$(awk -F '\t' '{print $1}' "$tmp_parsed" | tr '\n' ' ')
awk -v keys="$keys" '
BEGIN { n=split(keys,a," "); for(i=1;i<=n;i++) if(a[i]!="") drop[a[i]]=1 }
!($1 in drop) && $1!="awg_initdata" && $1!="awg_default_policy" && $1!="awg_clients" { print }
' "$settings" > "$tmp_settings"

while IFS="$(printf '\t')" read -r key value; do
    case "$key" in
        awg_address|awg_dns|awg_peer_allowedips) value=$(printf '%s' "$value" | sed 's/[[:space:]]//g') ;;
    esac
    printf '%s %s\n' "$key" "$value" >> "$tmp_settings"
done < "$tmp_parsed"

if [ -s "$tmp_init" ]; then
    initdata=$(base64 < "$tmp_init" | tr -d '\r\n')
    printf 'awg_initdata %s\n' "$initdata" >> "$tmp_settings"
fi
printf 'awg_default_policy direct\n' >> "$tmp_settings"
printf 'awg_clients \n' >> "$tmp_settings"

chmod 600 "$tmp_settings"
mv "$tmp_settings" "$settings"
chmod 600 "$settings"
echo "AmneziaWG settings imported"
