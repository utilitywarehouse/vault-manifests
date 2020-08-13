# Vault PKI manager

## Design

This is a bash script that manages Vault's TLS and distributes ca.crt to all
client namespaces.

It has ClusterRole that allows it to write configMaps cluster-wide.

Threat scenario for this design is if someone malicious can snoop network /
mitm network and present their own CA instead. The client would be handing over
their SA token.

By injecting the CA into the namespace, the attacker would also need permission
to write configMaps into target namespaces.
