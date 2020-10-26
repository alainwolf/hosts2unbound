# hosts2unbound

## About 

This script does three things:

1. Download your choice of multiple adblocking hosts files.
1. Convert the downloaded hosts files to Unbound DNS server local-zones, of your
   chosen zone-type.
1. Load the new local-zones into a running Unbound server, without server
   restart, preserving your servers DNS cache.


## Notes

### GitHub Raw File Downloads

Apparently the HTTP server for GitHub raw files doesn't send any 
`last-modified` data in its HTTP haders. I recommend using  alternative links, 
if posiible, to avoid re-processing the same data again and again.

You can test if a HTTP server sends a last-modified tag:

    $ curl -s -D /dev/stdout -o /dev/null http://sbc.io/hosts/hosts \
        | grep "Last-Modified:"
    Last-Modified: Mon, 19 Oct 2020 23:43:28 GMT

The following will not yeld any output:

    $ curl -s -D /dev/stdout -o /dev/null \
        https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
            | grep "Last-Modified:"



### local-zone and local-data

Traditionally scripts and advisories used a local-zone redirect and then provide
local-data to point A records to either `127.0.0.1` or more recently to `0.0.0.0`.

Some claimed for `0.0.0.0` being a better choice, as it would not lead to
useless connections to localhost as with `127.0.0.1`.

Unfortunately on Linux `0.0.0.0` is just silently treated as `127.0.0.1`:

    $ ping -c 3 0.0.0.0
    PING 0.0.0.0 (127.0.0.1) 56(84) bytes of data.
    64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.047 ms
    64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.048 ms
    64 bytes from 127.0.0.1: icmp_seq=3 ttl=64 time=0.046 ms

    --- 0.0.0.0 ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2025ms
    rtt min/avg/max/mdev = 0.046/0.047/0.048/0.000 ms

Unbound offers a wide range of choices of of local-zone types. documentation.
Any of `deny`, `refuse`, `static`, `always_refuse`, `always_nxdomain` will work,
as they don't need additional local-data.

See the
[unbound.conf](https://nlnetlabs.nl/documentation/unbound/unbound.conf/) man
page.

For now I use `refuse` in my configuration:

* I don't need a second line with local-data for every entry, cutting file-sizes
  and number of records parsed in half.
* Clients can see, that their query was refused instead of receiving a false
  answer.
* No connection attempts to localhost or anywhere else.

Like this:

    $ host ad.doubleclick.net
    Host ad.doubleclick.net not found: 5(REFUSED)

Or like this:

    $ nslookup ad.doubleclick.net
    Server:		127.0.0.1
    Address:	127.0.0.1#53

    ** server can't find ad.doubleclick.net: REFUSED


The downside of this aproach is that not only the host-address is blocked, but
any other query to that domain, i.e. MX records.
