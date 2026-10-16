# Crynwr packet driver collection (DOS)

`crynwr.zip` is the FreeDOS package of the Crynwr Software packet driver collection
(version 2006-09-02c, package date 2022-02-17), downloaded 2026-10-15 from the FreeDOS
repository: https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/repositories/1.3/net/crynwr.zip
(2,636,797 bytes, SHA1 `0585a5350ed90d8628eb6109ebb6db8fe1cbfb9c`, as listed on the
package page). Primary site: http://crynwr.com. License: GNU GPL (the collection's
COPYING.DOC; the sources are in the zip's `SOURCE` folder).

Used by `src\tools\net486.ps1 disk -Nic ne2000` for the NE2000 edition of the 486
network floppy (`dist\NET486NE`), meant for an emulated 486 (86Box with a Novell NE2000):

| File | What |
| --- | --- |
| `DRIVERS\CRYNWR\NE2000.COM` | the NE2000 packet driver: `NE2000 0x60 <irq> 0x300` (software interrupt, hardware IRQ, I/O base) |

The real 486 has a 3Com 3C509B and uses the 3Com packet driver from
`third_party\3com-etherdisk` instead (the default edition of the disk).
