package main

import (
	"bufio"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"os"
	"strings"
	"time"
)

type config struct {
	iface map[string]string
	peer  map[string]string
}

func parseConfig(path string) (config, error) {
	f, err := os.Open(path)
	if err != nil {
		return config{}, err
	}
	defer f.Close()

	c := config{iface: map[string]string{}, peer: map[string]string{}}
	section := ""
	s := bufio.NewScanner(f)
	for s.Scan() {
		line := strings.TrimSpace(s.Text())
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, ";") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = strings.ToLower(strings.TrimSpace(line[1 : len(line)-1]))
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			return config{}, fmt.Errorf("invalid configuration line")
		}
		key, value = strings.TrimSpace(key), strings.TrimSpace(value)
		switch section {
		case "interface":
			c.iface[key] = value
		case "peer":
			c.peer[key] = value
		default:
			return config{}, fmt.Errorf("setting outside Interface or Peer section")
		}
	}
	if err := s.Err(); err != nil {
		return config{}, err
	}
	for _, k := range []string{"PrivateKey", "HeaderProtectionKey"} {
		if c.iface[k] == "" {
			return config{}, fmt.Errorf("missing Interface.%s", k)
		}
	}
	for _, k := range []string{"PublicKey", "Endpoint", "AllowedIPs"} {
		if c.peer[k] == "" {
			return config{}, fmt.Errorf("missing Peer.%s", k)
		}
	}
	return c, nil
}

func keyHex(value string) (string, error) {
	b, err := base64.StdEncoding.DecodeString(strings.TrimSpace(value))
	if err != nil {
		return "", errors.New("invalid base64 key")
	}
	if len(b) != 32 {
		return "", fmt.Errorf("invalid key length %d", len(b))
	}
	return hex.EncodeToString(b), nil
}

func boolValue(value string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "yes", "true", "on":
		return "true", nil
	case "0", "no", "false", "off":
		return "false", nil
	default:
		return "", errors.New("invalid boolean value")
	}
}

func resolveEndpoint(value string) (string, error) {
	host, port, err := net.SplitHostPort(strings.TrimSpace(value))
	if err != nil {
		return "", errors.New("invalid endpoint")
	}
	if ip := net.ParseIP(host); ip != nil {
		return net.JoinHostPort(ip.String(), port), nil
	}
	ips, err := net.LookupIP(host)
	if err != nil || len(ips) == 0 {
		return "", errors.New("endpoint hostname did not resolve")
	}
	for _, ip := range ips {
		if v4 := ip.To4(); v4 != nil {
			return net.JoinHostPort(v4.String(), port), nil
		}
	}
	return net.JoinHostPort(ips[0].String(), port), nil
}

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: awg-uapi-config <interface> <config>")
		os.Exit(2)
	}
	name, path := os.Args[1], os.Args[2]
	c, err := parseConfig(path)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	privateKey, err := keyHex(c.iface["PrivateKey"])
	if err != nil {
		fmt.Fprintln(os.Stderr, "PrivateKey:", err)
		os.Exit(1)
	}
	headerKey, err := keyHex(c.iface["HeaderProtectionKey"])
	if err != nil {
		fmt.Fprintln(os.Stderr, "HeaderProtectionKey:", err)
		os.Exit(1)
	}
	publicKey, err := keyHex(c.peer["PublicKey"])
	if err != nil {
		fmt.Fprintln(os.Stderr, "PublicKey:", err)
		os.Exit(1)
	}
	endpoint, err := resolveEndpoint(c.peer["Endpoint"])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	lines := []string{"set=1", "private_key=" + privateKey, "replace_peers=true"}
	deviceKeys := []struct{ config, uapi string }{
		{"Jc", "jc"}, {"Jmin", "jmin"}, {"Jmax", "jmax"},
		{"S1", "s1"}, {"S2", "s2"}, {"S3", "s3"}, {"S4", "s4"},
		{"H1", "h1"}, {"H2", "h2"}, {"H3", "h3"}, {"H4", "h4"},
		{"I1", "i1"}, {"I2", "i2"}, {"I3", "i3"}, {"I4", "i4"}, {"I5", "i5"},
		{"ContentPaddingAddition", "content_padding_addition"},
		{"RekeyAfterTime", "rekey_after_time"}, {"RekeyTimeout", "rekey_timeout"},
		{"RejectAfterTime", "reject_after_time"}, {"KeepaliveTimeout", "keepalive_timeout"},
		{"MaxHandshakeAttempts", "max_handshake_attempts"},
	}
	for _, k := range deviceKeys {
		if v := c.iface[k.config]; v != "" {
			lines = append(lines, k.uapi+"="+v)
		}
	}
	lines = append(lines, "header_protection_key="+headerKey)
	for _, k := range []struct{ config, uapi string }{{"RandomTrailers", "random_trailers"}, {"DisableCookies", "disable_cookies"}} {
		if v := c.iface[k.config]; v != "" {
			parsed, err := boolValue(v)
			if err != nil {
				fmt.Fprintln(os.Stderr, k.config+":", err)
				os.Exit(1)
			}
			lines = append(lines, k.uapi+"="+parsed)
		}
	}
	lines = append(lines, "public_key="+publicKey)
	if v := c.peer["PresharedKey"]; v != "" {
		psk, err := keyHex(v)
		if err != nil {
			fmt.Fprintln(os.Stderr, "PresharedKey:", err)
			os.Exit(1)
		}
		lines = append(lines, "preshared_key="+psk)
	}
	lines = append(lines, "endpoint="+endpoint)
	if v := c.peer["PersistentKeepalive"]; v != "" {
		lines = append(lines, "persistent_keepalive_interval="+v)
	}
	lines = append(lines, "replace_allowed_ips=true")
	for _, allowed := range strings.Split(c.peer["AllowedIPs"], ",") {
		if allowed = strings.TrimSpace(allowed); allowed != "" {
			lines = append(lines, "allowed_ip="+allowed)
		}
	}
	lines = append(lines, "protocol_version=1")

	conn, err := net.DialTimeout("unix", "/var/run/amneziawg/"+name+".sock", 5*time.Second)
	if err != nil {
		fmt.Fprintln(os.Stderr, "UAPI socket:", err)
		os.Exit(1)
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(10 * time.Second))
	if _, err := fmt.Fprint(conn, strings.Join(lines, "\n")+"\n\n"); err != nil {
		fmt.Fprintln(os.Stderr, "UAPI write:", err)
		os.Exit(1)
	}
	response, err := bufio.NewReader(conn).ReadString('\n')
	if err != nil {
		fmt.Fprintln(os.Stderr, "UAPI read:", err)
		os.Exit(1)
	}
	if strings.TrimSpace(response) != "errno=0" {
		fmt.Fprintln(os.Stderr, "UAPI rejected configuration")
		os.Exit(1)
	}
	fmt.Printf("configured %s with AWG 3.1 parameters\n", name)
}
