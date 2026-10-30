package main

import (
	"context"
	"errors"
	stdnet "net"
	"reflect"
	"testing"
)

func TestAdvertisedICEIPs(t *testing.T) {
	tests := []struct {
		name, override, host string
		want                 []string
		dns                  bool
	}{
		{"IPv4 with port", "", "192.168.1.20:8080", []string{"192.168.1.20"}, false},
		{"IPv4", "", "192.168.1.20", []string{"192.168.1.20"}, false},
		{"IPv6 with port", "", "[2001:db8::1]:8080", []string{"2001:db8::1"}, false},
		{"IPv6", "", "[::1]", []string{"::1"}, false},
		{"override wins", "203.0.113.4", "browser.example:8080", []string{"203.0.113.4"}, false},
		{"empty override is auto", " ", "browser.example:8080", []string{"192.0.2.1", "2001:db8::1"}, true},
		{"DNS", "", "browser.example", []string{"192.0.2.1", "2001:db8::1"}, true},
		{"empty host", "", "", nil, false},
		{"invalid authority", "", "bad:host:8080", nil, false},
		{"not a URL", "", "https://browser.example", nil, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			called := false
			lookup := func(ctx context.Context, host string) ([]stdnet.IPAddr, error) {
				called = true
				if host != "browser.example" {
					t.Fatalf("unexpected DNS host %q", host)
				}
				if _, ok := ctx.Deadline(); !ok {
					t.Fatal("DNS needs bounded deadline")
				}
				return []stdnet.IPAddr{
					{IP: stdnet.ParseIP("192.0.2.1")},
					{IP: stdnet.ParseIP("192.0.2.2")},
					{IP: stdnet.ParseIP("2001:db8::1")},
				}, nil
			}
			got := advertisedICEIPs(context.Background(), tt.override, tt.host, lookup)
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("got %v, want %v", got, tt.want)
			}
			if called != tt.dns {
				t.Fatalf("DNS called = %v, want %v", called, tt.dns)
			}
		})
	}
}

func TestAdvertisedICEIPsDNSFailure(t *testing.T) {
	lookup := func(context.Context, string) ([]stdnet.IPAddr, error) {
		return nil, errors.New("unresolvable")
	}
	if got := advertisedICEIPs(context.Background(), "", "missing.example", lookup); len(got) != 0 {
		t.Fatalf("DNS failure should retain ordinary host gathering, got %v", got)
	}
}

func TestPeerAPIIndependent(t *testing.T) {
	// Simultaneous creation must not share mutable codecs, interceptors, or ICE settings.
	for _, ip := range []string{"192.0.2.1", "192.0.2.2"} {
		ip := ip
		t.Run(ip, func(t *testing.T) {
			t.Parallel()
			api, err := peerAPI(nil, []string{ip})
			if err != nil {
				t.Fatal(err)
			}
			if api == nil {
				t.Fatal("nil API")
			}
		})
	}
}
