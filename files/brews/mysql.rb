require 'formula'

class Mysql < Formula
  homepage 'http://dev.mysql.com/doc/refman/5.6/en/'
  url "http://cdn.mysql.com/Downloads/MySQL-5.6/mysql-5.6.19.tar.gz"
  sha1 "4b59d96642c62c26648826ea4f9c30dbf123dbed"
  version '5.6.19-boxen1'

  depends_on 'cmake' => :build
  depends_on 'pidof'

  fails_with :llvm do
    build 2326
    cause "https://github.com/mxcl/homebrew/issues/issue/144"
  end

  skip_clean :all # So "INSTALL PLUGIN" can work.

  option :universal
  option 'with-tests', 'Build with unit tests'
  option 'with-embedded', 'Build the embedded server'
  option 'with-archive-storage-engine', 'Compile with the ARCHIVE storage engine enabled'
  option 'with-blackhole-storage-engine', 'Compile with the BLACKHOLE storage engine enabled'
  option 'enable-local-infile', 'Build with local infile loading support'
  option 'enable-memcached', 'Enable innodb-memcached support'
  option 'enable-debug', 'Build with debug support'

  def install
    # Don't hard-code the libtool path. See:
    # https://github.com/Homebrew/homebrew/issues/20185
    inreplace "cmake/libutils.cmake",
      "COMMAND /usr/bin/libtool -static -o ${TARGET_LOCATION}",
      "COMMAND libtool -static -o ${TARGET_LOCATION}"

    # Build without compiler or CPU specific optimization flags to facilitate
    # compilation of gems and other software that queries `mysql-config`.
    ENV.minimal_optimization

    # -DINSTALL_* are relative to prefix
    args = %W[
      .
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DCMAKE_FIND_FRAMEWORK=LAST
      -DCMAKE_VERBOSE_MAKEFILE=ON
      -DMYSQL_DATADIR=#{var}/mysql
      -DINSTALL_INCLUDEDIR=include/mysql
      -DINSTALL_MANDIR=share/man
      -DINSTALL_DOCDIR=share/doc/#{name}
      -DINSTALL_INFODIR=share/info
      -DINSTALL_MYSQLSHAREDIR=share/mysql
      -DWITH_SSL=yes
      -DWITH_SSL=system
      -DDEFAULT_CHARSET=utf8
      -DDEFAULT_COLLATION=utf8_general_ci
      -DSYSCONFDIR=#{etc}
      -DCOMPILATION_COMMENT=Homebrew
      -DWITH_EDITLINE=system
    ]

    # To enable unit testing at build, we need to download the unit testing suite
    if build.with? 'tests'
      args << "-DENABLE_DOWNLOADS=ON"
    else
      args << "-DWITH_UNIT_TESTS=OFF"
    end

    # Build the embedded server
    args << "-DWITH_EMBEDDED_SERVER=ON" if build.with? 'embedded'

    # Compile with ARCHIVE engine enabled if chosen
    args << "-DWITH_ARCHIVE_STORAGE_ENGINE=1" if build.with? 'archive-storage-engine'

    # Compile with BLACKHOLE engine enabled if chosen
    args << "-DWITH_BLACKHOLE_STORAGE_ENGINE=1" if build.with? 'blackhole-storage-engine'

    # Make universal for binding to universal applications
    if build.universal?
      ENV.universal_binary
      args << "-DCMAKE_OSX_ARCHITECTURES=#{Hardware::CPU.universal_archs.as_cmake_arch_flags}"
    end

    # Build with local infile loading support
    args << "-DENABLED_LOCAL_INFILE=1" if build.include? 'enable-local-infile'

    # Build with memcached support
    args << "-DWITH_INNODB_MEMCACHED=1" if build.include? 'enable-memcached'

    # Build with debug support
    args << "-DWITH_DEBUG=1" if build.include? 'enable-debug'

    system "cmake", *args
    system "make"
    system "make install"

    # Don't create databases inside of the prefix!
    # See: https://github.com/Homebrew/homebrew/issues/4975
    rm_rf prefix+'data'

    # Link the setup script into bin
    bin.install_symlink prefix/"scripts/mysql_install_db"

    # Fix up the control script and link into bin
    inreplace "#{prefix}/support-files/mysql.server" do |s|
      s.gsub!(/^(PATH=".*)(")/, "\\1:#{HOMEBREW_PREFIX}/bin\\2")
      # pidof can be replaced with pgrep from proctools on Mountain Lion
      s.gsub!(/pidof/, 'pgrep') if MacOS.version >= :mountain_lion
    end

    bin.install_symlink prefix/"support-files/mysql.server"

    # Move mysqlaccess to libexec
    libexec.mkpath
    mv "#{bin}/mysqlaccess", libexec
    mv "#{bin}/mysqlaccess.conf", libexec
  end
end
