%define release %{rpm_release}%{?dist}

Summary: Daemon to serve Adobe Flash socket policy XML
Name: flashpolicyd
Version: %{version}
Release: %{release}
Group: System Tools
License: ASL 2
URL: http://code.google.com/p/flashpolicyd/
Source0: http://flashpolicyd.googlecode.com/files/flashpolicyd-%{version}.tgz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires: ruby
Requires(post): chkconfig
Requires(preun): chkconfig
Requires(preun): initscripts
Requires(postun): initscripts
BuildArch: noarch
Packager: R.I.Pienaar <rip@devco.net>

%description
Daemon to serve Adobe Flash socket policy XML

%prep
%setup -q -n flashpolicyd-%{version}

%build

%install
rm -rf %{buildroot}
%{__install} -d -m0755  %{buildroot}/etc/init.d
%{__install} -d -m0755  %{buildroot}/usr/sbin
%{__install} -d -m 755  %{buildroot}%{_docdir}/%{name}-%{version}/rdoc
%{__install} -m 755 flashpolicyd.init %{buildroot}/etc/init.d/flashpolicyd
%{__install} -m 755 flashpolicyd.rb %{buildroot}/usr/sbin/flashpolicyd
%{__install} flashpolicy.xml %{buildroot}/etc/flashpolicy.xml
%{__install} README %{buildroot}%{_docdir}/%{name}-%{version}/
%{__install} check_flashpolicyd.rb %{buildroot}%{_docdir}/%{name}-%{version}/

cp -R doc/* %{buildroot}%{_docdir}/%{name}-%{version}/rdoc/

%clean
rm -rf %{buildroot}

%post
/sbin/chkconfig --add flashpolicyd || :

%preun
if [ "$1" = 0 ] ; then
  /sbin/service flashpolicyd stop > /dev/null 2>&1
  /sbin/chkconfig --del flashpolicyd || :
fi

%postun
if [ "$1" -ge 1 ]; then
  /sbin/service flashpolicyd restart >/dev/null 2>&1 || :
fi

%files
%config /etc/flashpolicy.xml
%doc %{_docdir}/%{name}-%{version}
/usr/sbin/flashpolicyd
/etc/init.d/flashpolicyd

%changelog
* Thu Feb 10 2009 R.I.Pienaar <rip@devco.net>
- Create spec file
