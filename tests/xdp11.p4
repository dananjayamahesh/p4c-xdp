#include "xdp_model.p4"

header Ethernet {
    bit<48> source;
    bit<48> destination;
    bit<16> protocol;
}

header IPv4 {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

struct Headers {
    Ethernet ethernet;
    IPv4     ipv4;
}

parser Parser(packet_in packet, out Headers hd) {
    state start {
        packet.extract(hd.ethernet);
        transition select(hd.ethernet.protocol) {
            16w0x800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        packet.extract(hd.ipv4);
        transition select(hd.ipv4.protocol) {
            default: accept;
        }
    }
}

control Ingress(inout Headers hd, in xdp_input xin, out xdp_output xout) {

    bit<48> tmp;
    xdp_action xact = xdp_action.XDP_PASS; 

    apply {
		if (hd.ipv4.isValid())
		{
			tmp = hd.ethernet.destination;
			hd.ethernet.destination = hd.ethernet.source;
			hd.ethernet.source = tmp;
            xact = xdp_action.XDP_TX;
		}
        xout.output_port = 0;
        xout.output_action = xact;
    }
}

control Deparser(in Headers hdrs, packet_out packet) {
    apply {
        // we only need to emit ethernet header
        packet.emit(hdrs.ethernet);
    }
}

xdp(Parser(), Ingress(), Deparser()) main;