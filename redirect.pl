#!perl

use strict;
use warnings;

use Mojolicious::Lite -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);
use Data::Dumper;

sub retrieve_assets {
  my @rassets;
  my $ua  = Mojo::UserAgent->new;
  my $res = $ua->get('https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest')->result;
  unless ( $res->is_success ) {
    return @rassets;
  }
  my $releases = decode_json( $res->body );

  foreach my $rasset ( @{ $releases->{'assets'} } ) {
    push( @rassets, $rasset->{browser_download_url} );
  }

  return @rassets;
}

get '/#asset' => sub ($c) {
  my @rassets = retrieve_assets;

  if ( !@rassets ) {
    return $c->render( text => "Unable to retrieve asset list from api.github.com", status => '200' );
  }

  my $asset = $c->param('asset');
  my ( $file, $type ) = split( /\./, $asset );

  foreach my $rasset (@rassets) {
    my $rfile = ( split( '/', $rasset ) )[-1];
    if ( $rfile =~ m/\Q$asset/i ) {
      return $c->redirect_to($rasset);
    }
  }

  if ( defined $type ) {
    foreach my $rasset (@rassets) {
      my $rfile = ( split( '/', $rasset ) )[-1];
      if ( ( defined $type ) and ( $rfile =~ m/\Q$type/i ) ) {
        return $c->redirect_to($rasset);
      }
    }
  }

  if ( defined $file ) {
    foreach my $rasset (@rassets) {
      my $rfile = ( split( '/', $rasset ) )[-1];
      if ( $rfile =~ m/\Q$file/i ) {
        return $c->redirect_to($rasset);
      }
    }
  }

  return $c->render( text => "No matches found for $asset", status => '200' );
};

get '/*dummy' => { dummy => '' } => sub ($c) {
  my $remote_ua = $c->req->headers->user_agent;
  if ( $remote_ua =~ m/(wget|curl|fetch|powershell|ansible-httpget)/i ) {
    $c->render( 'help', format => 'txt' );
  } else {
    $c->render( 'help', format => 'html' );
  }
  return;
};
app->start;

__DATA__

@@ help.html.ep
<!DOCTYPE html>
<html>
<head>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
</head>
<body>
<div class="container">
<h2> Directly download the latest ZFSBootMenu assets </h2>
<a class="btn btn-primary" href="https://get.zfsbootmenu.org/latest.EFI"> ZFSBootMenu x86_64 EFI </a>
<a class="btn btn-primary" href="https://get.zfsbootmenu.org/latest.tar.gz"> ZFSBootMenu x86_64 Components </a>
<h2> Retrieve the latest ZFSBootMenu assets from the CLI</h2>
<pre>
curl https://get.zfsbootmenu.org/:asset
asset => [ 'efi', 'tar.gz', 'sha256.sig', 'sha256.txt' ]
</pre>
<h4> wget examples </h3>
<pre>
$ wget --content-disposition https://get.zfsbootmenu.org/efi
$ wget --content-disposition https://get.zfsbootmenu.org/tar.gz
$ wget --content-disposition https://get.zfsbootmenu.org/sha256.sig
</pre>
<h4> curl examples </h3>
<pre>
$ curl -O -L https://get.zfsbootmenu.org/zfsbootmenu.EFI
$ curl -O -L https://get.zfsbootmenu.org/zfsbootmenu.tar.gz
$ curl -O -L https://get.zfsbootmenu.org/sha256.sig
</pre>
Refer to <a href="https://github.com/zbm-dev/zfsbootmenu#signature-verification-and-prebuilt-efi-executables">zbm-dev/zfsbootmenu</a> for signature verification help.
</body>
</html>

@@ help.txt.ep
Retrieve the latest ZFSBootMenu assets

# wget, save as the official filename
$ wget --content-disposition https://get.zfsbootmenu.org/efi
$ wget --content-disposition https://get.zfsbootmenu.org/tar.gz
$ wget --content-disposition https://get.zfsbootmenu.org/sha256.sig

# curl, save as the filename passed to get.zfsbootmenu.org
$ curl -O -L https://get.zfsbootmenu.org/zfsbootmenu.EFI
$ curl -O -L https://get.zfsbootmenu.org/zfsbootmenu.tar.gz
$ curl -O -L https://get.zfsbootmenu.org/sha256.sig

Refer to https://github.com/zbm-dev/zfsbootmenu#signature-verification-and-prebuilt-efi-executables
