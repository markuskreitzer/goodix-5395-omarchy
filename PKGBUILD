pkgname=libfprint-goodix53x5
pkgver=1.94.10
pkgrel=10.1
pkgdesc="libfprint with the Goodix HTK32 27c6:5335/5385/5395 driver"
arch=('x86_64')
url="https://github.com/AndyHazz/goodix53x5-libfprint"
license=('LGPL-2.1-or-later')
depends=('libusb' 'libgusb' 'pixman' 'cairo' 'glib2' 'nss'
         'libjpeg-turbo' 'openssl' 'opencv')
makedepends=('git' 'meson' 'ninja' 'gcc' 'pkgconf' 'gtk-doc' 'glib2-devel'
             'gobject-introspection')
optdepends=('fprintd: fingerprint authentication daemon')
provides=('libfprint' 'libfprint-2' 'libfprint-2.so')
conflicts=('libfprint' 'libfprint-2')
options=(!debug)
install="$pkgname.install"
source=("git+https://gitlab.freedesktop.org/libfprint/libfprint.git#tag=v${pkgver}"
        "git+https://github.com/AndyHazz/goodix53x5-libfprint.git#commit=309d4c6999a1cdce172c1ca1ee81387b5078d38f")
sha256sums=('SKIP'
            'SKIP')

prepare() {
  cd "$srcdir/libfprint"
  cp -r "$srcdir/goodix53x5-libfprint/drivers/goodix53x5" libfprint/drivers/
  cp -r "$srcdir/goodix53x5-libfprint/sigfm" libfprint/
  patch -p1 < "$srcdir/goodix53x5-libfprint/meson-integration.patch"
}

build() {
  cd "$srcdir/libfprint"
  meson setup builddir --prefix=/usr -Dinstalled-tests=false -Ddoc=false -Dintrospection=false
  ninja -C builddir
}

package() {
  cd "$srcdir/libfprint"
  DESTDIR="$pkgdir" ninja -C builddir install
}
