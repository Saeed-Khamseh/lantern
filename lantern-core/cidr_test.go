package lanterncore

import (
	"reflect"
	"testing"

	"github.com/getlantern/radiance/vpn"
)

func TestCIDRBridgePreservesBatchAndFilterType(t *testing.T) {
	want := []string{"127.0.0.0/8", "::1/128"}
	filter := filterFromTypeAndItems(vpn.TypeIPCIDR, []string{"127.0.0.0/8, ::1/128"})
	if !reflect.DeepEqual(filter.IPCIDR, want) {
		t.Fatalf("unexpected CIDR batch: %v", filter.IPCIDR)
	}
	if !reflect.DeepEqual(itemsForType(filter, vpn.TypeIPCIDR), want) {
		t.Fatal("CIDR read-back must preserve the list")
	}
	if len(filter.DomainSuffix) != 0 || len(filter.ProcessPath) != 0 {
		t.Fatal("CIDR import must not populate domain or application filters")
	}
}

