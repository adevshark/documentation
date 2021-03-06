#global git 9712e920bdeefba455f7191f5ce7d1a61d81b708

Name:           php-LC-openvpn-connection-manager
Version:        1.0.3
Release:        1%{?dist}
Summary:        Manage client connections to OpenVPN processes

License:        MIT
URL:            https://software.tuxed.net/php-openvpn-connection-manager
%if %{defined git}
Source0:        https://git.tuxed.net/LC/php-openvpn-connection-manager/snapshot/php-openvpn-connection-manager-%{git}.tar.xz
%else
Source0:        https://software.tuxed.net/php-openvpn-connection-manager/files/php-openvpn-connection-manager-%{version}.tar.xz
Source1:        https://software.tuxed.net/php-openvpn-connection-manager/files/php-openvpn-connection-manager-%{version}.tar.xz.asc
Source2:        gpgkey-6237BAF1418A907DAA98EAA79C5EDD645A571EB2
%endif

BuildArch:      noarch

BuildRequires:  gnupg2
BuildRequires:  php-fedora-autoloader-devel
BuildRequires:  %{_bindir}/phpab
#    "require-dev": {
#        "phpunit/phpunit": "^4|^5|^6|^7"
#    },
%if 0%{?fedora} >= 28 || 0%{?rhel} >= 8
BuildRequires:  phpunit7
%global phpunit %{_bindir}/phpunit7
%else
BuildRequires:  phpunit
%global phpunit %{_bindir}/phpunit
%endif
#    "require": {
#        "php": ">=5.4",
#        "psr/log": "^1.0"
#    },
BuildRequires:  php(language) >= 5.4.0
BuildRequires:  php-composer(psr/log)

#    "require": {
#        "php": ">=5.4",
#        "psr/log": "^1.0"
#    },
Requires:       php(language) >= 5.4.0
Requires:       php-composer(psr/log)

Provides:       php-composer(lc/openvpn-connection-manager) = %{version}

%description
Simple library written in PHP to manage client connections to OpenVPN processes 
through the OpenVPN management socket.

%prep
%if %{defined git}
%autosetup -n php-openvpn-connection-manager-%{git}
%else
gpgv2 --keyring %{SOURCE2} %{SOURCE1} %{SOURCE0}
%autosetup -n php-openvpn-connection-manager-%{version}
%endif

%build
%{_bindir}/phpab -t fedora -o src/autoload.php src
cat <<'AUTOLOAD' | tee -a src/autoload.php
require_once '%{_datadir}/php/Psr/Log/autoload.php';
AUTOLOAD

%install
mkdir -p %{buildroot}%{_datadir}/php/LC/OpenVpn
cp -pr src/* %{buildroot}%{_datadir}/php/LC/OpenVpn

%check
%{_bindir}/phpab -o tests/autoload.php tests
cat <<'AUTOLOAD' | tee -a tests/autoload.php
require_once 'src/autoload.php';
AUTOLOAD

%{phpunit} tests --verbose --bootstrap=tests/autoload.php

%files
%license LICENSE
%doc composer.json CHANGES.md README.md
%dir %{_datadir}/php/LC
%{_datadir}/php/LC/OpenVpn

%changelog
* Mon Apr 01 2019 François Kooman <fkooman@tuxed.net> - 1.0.3-1
- update to 1.0.3

* Sun Sep 09 2018 François Kooman <fkooman@tuxed.net> - 1.0.2-7
- merge dev and prod spec files in one
- cleanup requirements

* Sat Sep 08 2018 François Kooman <fkooman@tuxed.net> - 1.0.2-6
- move some stuff around to make it consistent with other spec files

* Sun Aug 05 2018 François Kooman <fkooman@tuxed.net> - 1.0.2-5
- use phpunit7 on supported platforms

* Mon Jul 23 2018 François Kooman <fkooman@tuxed.net> - 1.0.2-4
- add missing BR

* Mon Jul 23 2018 François Kooman <fkooman@tuxed.net> - 1.0.2-3
- use fedora phpab template for generating autoloader

* Thu Jun 28 2018 François Kooman <fkooman@tuxed.net> - 1.0.2-2
- use release tarball instead of Git tarball
- verify GPG signature

* Wed Jun 13 2018 François Kooman <fkooman@tuxed.net> - 1.0.2-1
- update to 1.0.2

* Thu Jun 07 2018 François Kooman <fkooman@tuxed.net> - 1.0.1-1
- update to 1.0.1

* Wed Jun 06 2018 François Kooman <fkooman@tuxed.net> - 1.0.0-2
- update upstream source URL

* Tue Jun 05 2018 François Kooman <fkooman@tuxed.net> - 1.0.0-1
- initial package
