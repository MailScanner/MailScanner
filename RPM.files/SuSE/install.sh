#!/usr/bin/env bash
#
# MailScanner installation script for SuSE based systems
# 
# This script installs the required software for
# MailScanner via zypper and CPAN based on user input.  
#
# Tested distributions: 	SuSE 13.2
#
# Written by:
# Jerry Benton < mailscanner@mailborder.com >
# 27 FEB 2015

# clear the screen. yay!
clear

# where i started for RPM install
THISCURRPMDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Function used to Wait for n seconds
timewait () {
	DELAY=$1
	sleep $DELAY
}

# Check for root user
if [ $(whoami) != "root" ]; then
	clear
	echo;
	echo "Installer must be run as root. Aborting. Use 'su -' to switch to the root environment."; echo;
	exit 192
fi

# bail if yum is not installed
if [ ! -x '/usr/bin/zypper' ]; then
	clear
	echo;
	echo "Zypper package manager is not installed. You must install this before starting";
	echo "the MailScanner installation process. Installation aborted."; echo;
	exit 192
else
	ZYPPER='/usr/bin/zypper';
fi

# confirm the RHEL release is known before continuing
if [ -f '/etc/redhat-release' ]; then
	# this is mostly to prevent accidental installation on a non redhat based system
	echo "This appears to be a Red Hat based system. This installer is for SuSE. Installation aborted."; echo;
	exit 192
fi

# basic test to see if we can ping google
if ping -c 1 8.8.8.8 > /dev/null; then
	# got a return on the single ping request
    CONNECTTEST=
else
	# a ping return isn't required, but it may signal a problem with the network connection. this simply warns the user
    CONNECTTEST="WARNING: I was unable to ping outside of your network. \nYou may ignore this warning if you have confirmed your connection is valid."
fi

# user info screen before the install process starts
echo "MailScanner Installation for SuSE Based Systems"; echo; echo;
echo "This will INSTALL or UPGRADE the required software for MailScanner on SuSE based systems";
echo "via the zypper package manager. Tested distributions are SuSE 13.2 and associated";
echo "variants. Internet connectivity is required for this installation script to execute."; 
echo;
echo -e $CONNECTTEST
echo;
echo "You may press CTRL + C at any time to abort the installation. Note that you may see";
echo "some errors during the perl module installation. You may safely ignore errors regarding";
echo "failed tests if you opt to use CPAN. You may also ignore 'No package available' notices";
echo "during the zypper installation of packages."; echo;
echo "When you are ready to continue, press return ... ";
read foobar

# if already installed, offer to upgrade the mailscanner.conf
AUTOUPGRADE=0
if [ -f '/etc/MailScanner/MailScanner.conf' ]; then
	clear
	echo;
	echo "Automatically upgrade MailScanner.conf?"; echo;
	echo "Based on a system analysis, I think you are performing an upgrade. Would you like to";
	echo "automatically upgrade /etc/MailScanner/MailScanner.conf to the new version? If you ";
	echo "elect not to upgrade it automatically, you will need to manually run the upgrade";
	echo "script after installation. If this in fact a new installation and not an upgrade, you";
	echo "can just enter 'N' or 'no' to ignore this.";
	echo;
	echo "Recommended: Y (yes)"; echo;
	read -r -p "Auto upgrade MailScanner.conf? [n/Y] : " response
	
	if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
		# user wants to auto upgrade mailscanner.conf
		AUTOUPGRADE=1
	elif [ -z $response ]; then    
		# user wants to auto upgrade mailscanner.conf
		AUTOUPGRADE=1
    else
    	# no auto upgrade
    	AUTOUPGRADE=0
    fi
fi

# ask if the user wants an mta installed
clear
echo;
echo "Do you want to install a Mail Transfer Agent (MTA)?"; echo;
echo "I can install an MTA via the zypper package manager to save you the trouble of having to do";
echo "this later. If you plan on using an MTA that is not listed below, you will have install ";
echo "it manually yourself if you have not already done so.";
echo;
echo "1 - sendmail";
echo "2 - postfix";
echo "3 - exim";
echo "N - Do not install";
echo;
echo "Recommended: 1 (sendmail)"; echo;
read -r -p "Install an MTA? [1] : " response

if [[ $response =~ ^([nN][oO])$ ]]; then
    # do not install
    MTAOPTION=
elif [ -z $response ]; then    
	# sendmail default
    MTAOPTION="sendmail";
elif [ $response == 1 ]; then    
	# sendmail 
    MTAOPTION="sendmail";    
elif [ $response == 2 ]; then    
	# sendmail 
    MTAOPTION="postfix";
elif [ $response == 3 ]; then    
	# sendmail 
    MTAOPTION="exim";        
else
	MTAOPTION=
fi

# clamav
clear
echo;
echo "Do you want to install or update Clam AV during this installation process?"; echo;
echo "This package is recommended unless you plan on using a different virus scanner.";
echo "Note that you may use more than one virus scanner at once with MailScanner.";
echo;
echo "Even if you already have Clam AV installed you should select this option so I";
echo "will know to check the clamav-wrapper and make corrections if required.";
echo;
echo "Recommended: Y (yes)"; echo;
read -r -p "Install or update Clam AV? [n/Y] : " response

if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
	# user wants clam av installed
	# some of these options may result in a 'no package available' on
	# some distributions, but that is ok
	CAV=1
	CAVOPTION="clamav";
elif [ -z $response ]; then  
	CAV=1
	CAVOPTION="clamav";
else
	# user does not want clam av
	CAV=0
	CAVOPTION=
fi
	
# ask if the user wants spamassassin installed
clear
echo;
echo "Do you want to install or update Spamassassin?"; echo;
echo "This package is recommended unless you have your own spam detection solution.";
echo;
echo "Recommended: Y (yes)"; echo;
read -r -p "Install or update Spamassassin? [n/Y] : " response

if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # user wants SA installed
    SA=1
    SAOPTION="spamassassin"
elif [ -z $response ]; then    
	# user wants SA installed
    SA=1
    SAOPTION="spamassassin"
else
    # user does not want SA
	SA=0
	SAOPTION=
fi

# ask if the user wants bonus perl modules installed
clear
echo;
echo "Do you want to install recommended Perl modules?"; echo;
echo "I will automatically attempt to install the required Perl modules, but I";
echo "can also attempt to install additional recommended modules. Do you want to";
echo "install additional recommended Perl modules?";
echo;
echo "Recommended: Y (yes)"; echo;
read -r -p "Install recommended Perl modules? [n/Y] : " response

if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # user wants extra installed
    NICETOHAVE=1
elif [ -z $response ]; then    
	# user wants extra installed
    NICETOHAVE=1
else
    # user does not want extra
	NICETOHAVE=0
fi

# ask if the user wants missing modules installed via CPAN
clear
echo;
echo "Do you want to install missing perl modules via CPAN?"; echo;
echo "I will attempt to install Perl modules via zypper, but some may not be unavailable during the";
echo "installation process. Missing modules will likely cause MailScanner to malfunction.";
echo;
echo "Recommended: Y (yes)"; echo;
read -r -p "Install missing Perl modules via CPAN? [n/Y] : " response

if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # user wants to use CPAN for missing modules
	CPANOPTION=1
	
	# rpm install will fail if the modules were not installed via RPM
	# so i am setting the --nodeps flag here since the user elected to 
	# use CPAN to remediate the modules
	NODEPS='--nodeps';
elif [ -z $response ]; then 
	 # user wants to use CPAN for missing modules
	CPANOPTION=1
	
	# rpm install will fail if the modules were not installed via RPM
	# so i am setting the --nodeps flag here since the user elected to 
	# use CPAN to remediate the modules
	NODEPS='--nodeps';
else
    # user does not want to use CPAN
    CPANOPTION=0
fi

# ask if the user wants to install the Mail::ClamAV module
if [ "$CPANOPTION" = "1" ]; then
	# Mail::ClamAV
	clear
	echo;
	echo "Do you want to install Mail::ClamAV via CPAN?"; echo;
	echo "If you are using Clam AV I can install the perl module that supports command line";
	echo "scanning via Perl and Clam AV. This is only required if you are not going to use";
	echo "the Clam AV daemon. However, it does not hurt to have this module available.";
	echo;
	echo "Note: If using Clam AV it is recommended that you use the Clam AV daemon.";
	echo;
	echo "Recommended: N (no)"; echo;
	read -r -p "Install missing Mail::ClamAV module via CPAN? [y/N] : " response
	
	if [ "$response" = "yes" ]; then
		# user wants to use CPAN for clam av module
		CAV=1
	elif [ "$response" = "y" ]; then
		# user wants to use CPAN for clam av module
		CAV=1
	elif [ "x$response" = "x" ]; then     
		# user does not want to use CPAN for clam av module
		CAV=0
	else
		# user does not want to use CPAN for clam av module
		CAV=0
	fi
	
	# Mail::SpamAssassin
	clear
	echo;
	echo "Will you be using Spamassassin?"; echo;
	echo "If you are using spamassassin I can verify that the Mail::SpamAssassin perl module is ";
	echo "installed. Normally the spamassassin package will install the module by default, but I";
	echo "can verify this and install it via CPAN if missing. Enter 'n' or 'no' if you will not ";
	echo "be using spamassassin.";
	echo;
	echo "Recommended: Y (yes)"; echo;
	read -r -p "Install missing Mail::SpamAssassin module via CPAN? [n/Y] : " response
	
	if [ "$response" = "yes" ]; then
		# user wants to use CPAN for SpamAssassin module
		SA=1
	elif [ "$response" = "y" ]; then
		# user wants to use CPAN for SpamAssassin module
		SA=1
	elif [ "x$response" = "x" ]; then  
		# user does want to use CPAN for SpamAssassin module
		SA=1
	else
		# user does not want to use CPAN for SpamAssassin module
		SA=0
	fi
else
	# don't install if not using CPAN
	CAV=0
	SA=0
fi

# ask if the user wants to ignore dependencies. they are automatically ignored
# if the user elected the CPAN option as explained above
if [ $CPANOPTION != 1 ]; then
	clear
	echo;
	echo "Do you want to ignore MailScanner dependencies?"; echo;
	echo "This will force install the MailScanner RPM package regardless of missing"; 
	echo "dependencies. It is highly recommended that you DO NOT do this unless you"; 
	echo "are debugging.";
	echo;
	echo "Recommended: N (no)"; echo;
	read -r -p "Ignore MailScanner dependencies (nodeps)? [y/N] : " response

	if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
		# user wants to ignore deps
		NODEPS='--nodeps'
	else
		# requiring deps
		NODEPS=
	fi
fi

# base system packages
BASEPACKAGES="binutils gcc glibc-devel libaio1 patch make man-pages patch rpm tar time unzip which zip libtool perl curl wget openssl libopenssl-devel bzip2 tnef unrar razor-agents";

# Packages available in the suse base 13.2. If the user elects not to use EPEL or if the 
# package is not available for their distro release it will be ignored during the install.
#
MOREPACKAGES="perl-Archive-Zip perl-Convert-BinHex perl-Convert-TNEF perl-DBD-SQLite perl-DBI perl-Digest-HMAC perl-Digest-SHA1 perl-ExtUtils-MakeMaker perl-File-ShareDir-Install perl-File-Temp perl-Filesys-Df perl-Getopt-Long-Descriptive perl-IO-stringy perl-HTML-Parser perl-HTML-Tagset perl-Inline perl-Mail-DKIM perl-Mail-SPF perl-MailTools perl-MIME-tools perl-Net-CIDR-Set perl-Net-DNS perl-Net-IP perl-OLE-Storage_Lite perl-Scalar-List-Utils perl-razor-agents perl-Sys-Hostname-Long perl-Sys-SigAction perl-Test-Pod perl-TimeDate perl-URI ";

# the array of perl modules needed
ARMOD=();
ARMOD+=('Archive::Tar'); 		ARMOD+=('Archive::Zip');		ARMOD+=('bignum');				
ARMOD+=('Carp');				ARMOD+=('Compress::Zlib');		ARMOD+=('Compress::Raw::Zlib');	
ARMOD+=('Convert::BinHex'); 	ARMOD+=('Convert::TNEF');		ARMOD+=('Data::Dumper');		
ARMOD+=('Date::Parse');			ARMOD+=('DBD::SQLite');			ARMOD+=('DBI');					
ARMOD+=('Digest::HMAC');		ARMOD+=('Digest::MD5');			ARMOD+=('Digest::SHA1'); 		
ARMOD+=('DirHandle');			ARMOD+=('ExtUtils::MakeMaker');	ARMOD+=('Fcntl');				
ARMOD+=('File::Basename');		ARMOD+=('File::Copy');			ARMOD+=('File::Path');			
ARMOD+=('File::Spec');			ARMOD+=('File::Temp');			ARMOD+=('FileHandle');			
ARMOD+=('Filesys::Df');			ARMOD+=('Getopt::Long');		ARMOD+=('Inline::C');			
ARMOD+=('IO');					ARMOD+=('IO::File');			ARMOD+=('IO::Pipe');			
ARMOD+=('IO::Stringy');			ARMOD+=('HTML::Entities');		ARMOD+=('HTML::Parser');		
ARMOD+=('HTML::Tagset');		ARMOD+=('HTML::TokeParser');	ARMOD+=('Mail::Field');			
ARMOD+=('Mail::Header');		ARMOD+=('Mail::IMAPClient');	ARMOD+=('Mail::Internet');		
ARMOD+=('Math::BigInt');		ARMOD+=('Math::BigRat');		ARMOD+=('MIME::Base64');		
ARMOD+=('MIME::Decoder');		ARMOD+=('MIME::Decoder::UU');	ARMOD+=('MIME::Head');			
ARMOD+=('MIME::Parser');		ARMOD+=('MIME::QuotedPrint');	ARMOD+=('MIME::Tools');			
ARMOD+=('MIME::WordDecoder');	ARMOD+=('Net::CIDR');			ARMOD+=('Net::DNS');			
ARMOD+=('Net::IP');				ARMOD+=('OLE::Storage_Lite');	ARMOD+=('Pod::Escapes');		
ARMOD+=('Pod::Simple');			ARMOD+=('POSIX');				ARMOD+=('Scalar::Util');		
ARMOD+=('Socket'); 				ARMOD+=('Storable'); 	 	 	ARMOD+=('Test::Harness');		
ARMOD+=('Test::Pod');			ARMOD+=('Test::Simple');		ARMOD+=('Time::HiRes');			
ARMOD+=('Time::localtime'); 	ARMOD+=('Sys::Hostname::Long');	ARMOD+=('Sys::SigAction');		
ARMOD+=('Sys::Syslog'); 		ARMOD+=('Env'); 				ARMOD+=('File::ShareDir::Install');

# not required but nice to have
if [ "$NICETOHAVE" = "1" ]; then
	ARMOD+=('bignum');				ARMOD+=('Business::ISBN');		ARMOD+=('Business::ISBN::Data');
	ARMOD+=('Data::Dump');			ARMOD+=('DB_File');				ARMOD+=('DBD::SQLite');
	ARMOD+=('DBI');					ARMOD+=('Digest');				ARMOD+=('Encode::Detect');
	ARMOD+=('Error');				ARMOD+=('ExtUtils::CBuilder');	ARMOD+=('ExtUtils::ParseXS');
	ARMOD+=('Getopt::Long');		ARMOD+=('Inline');				ARMOD+=('IO::String');	
	ARMOD+=('IO::Zlib');			ARMOD+=('IP::Country');			ARMOD+=('Mail::SPF');
	ARMOD+=('Mail::SPF::Query');	ARMOD+=('Module::Build');		ARMOD+=('Net::CIDR::Lite');
	ARMOD+=('Net::DNS');			ARMOD+=('Net::LDAP');			ARMOD+=('Net::DNS::Resolver::Programmable');
	ARMOD+=('NetAddr::IP');			ARMOD+=('Parse::RecDescent');	ARMOD+=('Test::Harness');
	ARMOD+=('Test::Manifest');		ARMOD+=('Text::Balanced');		ARMOD+=('URI');	
	ARMOD+=('version');				ARMOD+=('Digest');				ARMOD+=('Digest');	
fi

# add to array if the user is installing spamassassin
if [ $SA == 1 ]; then
	ARMOD+=('Mail::SpamAssassin');
fi

# add to array if the user is installing clam av
if [ $CAV == 1 ]; then
	ARMOD+=('Mail::ClamAV');
fi

# logging starts here
(
clear
echo;
echo "Installation results are being logged to mailscanner-install.log";
echo;
timewait 1

# install the basics
echo "Installing required base system utilities.";
echo;
timewait 2

# install base packages
$ZYPPER --non-interactive install $BASEPACKAGES

# install this separate in case it conflicts
if [ "x$MTAOPTION" != "x" ]; then
	$ZYPPER --non-interactive install $MTAOPTION
fi

# make sure rpm is available
if [ -x /bin/rpm ]; then
	RPM=/bin/rpm
elif [ -x /usr/bin/rpm ]; then
	RPM=/usr/bin/rpm
else
	clear
	echo;
	echo "The 'rpm' command cannot be found. I have already attempted to install this";
	echo "package, but it is still not found. Please ensure that you have network";
	echo "access to the internet and try running the installation again.";
	echo;
	exit 1
fi

# make sure the patch command is available
if [ ! -x /usr/bin/patch ]; then
	clear
	echo;
	echo "The patch command cannot be found. I have already attempted to install this";
	echo "package, but it is still not found. Please ensure that you have network access";
	echo "to the internet and try running the installation again.";
	echo;
	exit 1
else
	PATCH='/usr/bin/patch';
fi

# check for curl
if [ ! -x /usr/bin/curl ]; then
	clear
	echo;
	echo "The curl command cannot be found. I have already attempted to install this";
	echo "package, but it is still not found. Please ensure that you have network access";
	echo "to the internet and try running the installation again.";
	echo;
	exit 1
else
	CURL='/usr/bin/curl';
fi

# create the cpan config if there isn't one and the user
# elected to use CPAN
if [ $CPANOPTION == 1 ]; then
	# user elected to use CPAN option
	if [ ! -f '/root/.cpan/CPAN/MyConfig.pm' ]; then
		echo;
		echo "CPAN config missing. Creating one ..."; echo;
		mkdir -p /root/.cpan/CPAN
		cd /root/.cpan/CPAN
		$CURL -O https://s3.amazonaws.com/mailscanner/install/cpan/MyConfig.pm
		cd $THISCURRPMDIR
		timewait 1
	fi
fi

# install required perl packages that are available via zypper along
#
# some items may not be available depending on the distribution 
# release but those items will be checked after this and installed
# via cpan if the user elected to do so.
clear
echo;
echo "Installing available Perl packages, Clam AV (if elected), and ";
echo "Spamassassin (if elected) via zypper. You can safely ignore any";
echo "subsequent warnings from zypper."; echo;
timewait 3
$ZYPPER --non-interactive install $MOREPACKAGES $CAVOPTION $SAOPTION

# now check for missing perl modules and install them via cpan
# if the user elected to do so
clear; echo;
echo "Checking Perl Modules ... "; echo;
timewait 2
# used to trigger a wait if something this missing
PMODWAIT=0

# first try to install missing perl modules via zypper
# using this trick
for i in "${ARMOD[@]}"
do
	perldoc -l $i >/dev/null 2>&1
	if [ $? != 0 ]; then
		echo "$i is missing. Trying to install via Zypper ..."; echo;
		THING="'perl($i)'";
		$ZYPPER --non-interactive install $THING
	fi
done

for i in "${ARMOD[@]}"
do
	perldoc -l $i >/dev/null 2>&1
	if [ $? != 0 ]; then
		if [ $CPANOPTION == 1 ]; then
			clear
			echo "$i is missing. Installing via CPAN ..."; echo;
			timewait 1
			perl -MCPAN -e "CPAN::Shell->force(qw(install $i ));"
		else
			echo "WARNING: $i is missing. You should fix this.";
			PMODWAIT=5
		fi
	else
		echo "$i => OK";
	fi
done

# will pause if a perl module was missing
timewait $PMODWAIT

# get the public signing key for the mailscanner rpm
cd /tmp
rm -f jb_ms_rpm_public.key
$CURL -O https://s3.amazonaws.com/mailscanner/gpg/jb_ms_rpm_public.key
rpm --import jb_ms_rpm_public.key
rm -f jb_ms_rpm_public.key
cd $THISCURRPMDIR

clear
echo;
echo "Installing the MailScanner RPM ... ";

# using --force option to reinstall the rpm if the same version is
# already installed. this will not overwrite configuration files
# as they are protected in the rpm spec file
$RPM -Uvh --force $NODEPS mailscanner*noarch.rpm

# fix the clamav wrapper if the user does not exist
if [ -f '/etc/freshclam.conf' ]; then
	if id -u vscan >/dev/null 2>&1; then
		#clam is being used instead of clamav
		OLDCAVUSR='ClamUser="clamav"';
		NEWCAVUSR='ClamUser="vscan"'
	
		OLDCAVGRP='ClamGroup="clamav"';
		NEWCAVGRP='ClamGroup="vscan"';
	
		perl -pi -e 's/'$OLDCAVUSR'/'$NEWCAVUSR'/;' /usr/share/MailScanner/clamav-wrapper
		perl -pi -e 's/'$OLDCAVGRP'/'$NEWCAVGRP'/;' /usr/share/MailScanner/clamav-wrapper
		
		mkdir -p /var/run/clamav
		chown vscan:vscan /var/run/clamav
		freshclam
	fi
fi

if [ $? != 0 ]; then
	echo;
	echo '----------------------------------------------------------';
	echo 'Installation Error'; echo;
	echo 'The MailScanner RPM failed to install. Address the required';
	echo 'dependencies and run the installer again. Note that electing';
	echo 'to use CPAN should resolve dependency errors.';
	echo;
	echo 'Note that Perl modules need to be available system-wide. A';
	echo 'common issue is that missing modules were installed in a ';
	echo 'user specific configuration.';
	echo;
else
	if [ $AUTOUPGRADE == 1 ]; then
		echo "Upgrading /etc/MailScanner/MailScanner.conf";
		echo;
		echo "Your old configuration file will be saved as:";
		echo "/etc/MailScanner/MailScanner.conf.old.$$";
		echo;
		timewait 1
		
		# fix old style clamav Monitors if preset in old mailscanner.conf
		CAVOLD='Monitors for ClamAV Updates = /usr/local/share/clamav/*.cld /usr/local/share/clamav/*.cvd';
		CAVNEW='Monitors for ClamAV Updates = /usr/local/share/clamav/*.cld /usr/local/share/clamav/*.cvd /var/lib/clamav/*.inc/* /var/lib/clamav/*.?db /var/lib/clamav/*.cvd';
		perl -pi -e 's/'$CAVOLD'/'$CAVNEW'/;' /etc/MailScanner/MailScanner.conf
		
		upgrade_MailScanner_conf /etc/MailScanner/MailScanner.conf /etc/MailScanner/MailScanner.conf.rpmnew > /etc/MailScanner/MailScanner.new
		mv -f /etc/MailScanner/MailScanner.conf /etc/MailScanner/MailScanner.conf.old.$$
		mv -f /etc/MailScanner/MailScanner.new  /etc/MailScanner/MailScanner.conf
		
	fi
	
	echo;
	echo '----------------------------------------------------------';
	echo 'Installation Complete'; echo;
	echo 'See http://www.mailscanner.info for more information and  '
	echo 'support via the MailScanner mailing list.'
	echo;
fi 

) 2>&1 | tee mailscanner-install.log