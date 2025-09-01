#!perl

use strict;
use warnings;

use Mojolicious::Lite -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);

get '/#asset/#build' => { build => 'release' } => sub ($c) {
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

  my $tag_name = $releases->{'tag_name'};
  push( @rassets, "https://github.com/zbm-dev/zfsbootmenu/archive/refs/tags/$tag_name.tar.gz" );

  if ( !@rassets ) {
    return $c->render( text => "Unable to retrieve asset list from api.github.com", status => '200' );
  }

  my $asset = $c->param('asset');
  if ( $asset eq "components" ) {
    $asset = "tar.gz";
  }

  # The KCL writer and zbm-builder.sh scripts are not versioned
  my $raw_base_url = "https://raw.githubusercontent.com/zbm-dev/zfsbootmenu/master";
  if ( $asset =~ m/zbm-builder.sh/ ) {
    my $rasset = "$raw_base_url/$asset";
    return $c->redirect_to($rasset);
  }
  if ( $asset =~ m/zbm-kcl/ ) {
    my $rasset = "$raw_base_url/bin/$asset";
    return $c->redirect_to($rasset);
  }

  # There are no build styles for signatures
  if ( $asset =~ m/(sha256|txt|sig)/ ) {
    foreach my $rasset (@rassets) {
      my $rfile = ( split( '/', $rasset ) )[-1];
      if ( $rfile =~ m/\Q$asset/i ) {
        return $c->redirect_to($rasset);
      }
    }
  }

  # source is a special case
  if ( $asset =~ m/source/ ) {
    foreach my $rasset (@rassets) {
      if ( $rasset =~ m@\Qarchive/refs/tags@i ) {
        return $c->redirect_to($rasset);
      }
    }
  }

  my $build = $c->param('build');
  my ( $file, $type ) = split( /\./, $asset );

  # Match against the full filename
  foreach my $rasset (@rassets) {
    my $rfile = ( split( '/', $rasset ) )[-1];
    if ( $rfile =~ m/\Q$asset/i and $rfile =~ m/\Q$build/i ) {
      return $c->redirect_to($rasset);
    }
  }

  if ( defined $type ) {
    foreach my $rasset (@rassets) {
      my $rfile = ( split( '/', $rasset ) )[-1];
      if ( $rfile =~ m/\Q$type/i and $rfile =~ m/\Q$build/i ) {
        return $c->redirect_to($rasset);
      }
    }
  }

  if ( defined $file ) {
    foreach my $rasset (@rassets) {
      my $rfile = ( split( '/', $rasset ) )[-1];
      if ( $rfile =~ m/\Q$file/i and $rfile =~ m/\Q$build/i ) {
        return $c->redirect_to($rasset);
      }
    }
  }

  return $c->render( text => "No matches found for $asset", status => '200' );
};

get '/*dummy' => { dummy => '' } => sub ($c) {
  my $remote_ua = $c->req->headers->user_agent;
  if ( ( not length $remote_ua ) or ( $remote_ua =~ m/(wget|curl|fetch|powershell|ansible-httpget)/i ) ) {
    $c->render( 'help', format => 'txt' );
  } else {
    $c->render( 'help', format => 'html' );
  }
  return;
};

plugin SetUserGroup => { user => "nobody", group => "nogroup" };
my $listen = defined( $ENV{'PORT'} ) ? $ENV{'PORT'} : '8081';
app->config( hypnotoad => { listen => ["http://127.0.0.1:$listen"] } );
app->start;

__DATA__

@@ help.html.ep
% my $url = url_for->to_abs->scheme('https');
<!DOCTYPE html>
<html>
<head>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
</head>
<body>
<div class="container">
<h2> Directly download the latest ZFSBootMenu assets </h2>
<a class="btn btn-primary" href="<%= $url %>latest.EFI"> ZFSBootMenu x86_64 EFI </a>
<a class="btn btn-primary" href="<%= $url %>latest.tar.gz"> ZFSBootMenu x86_64 Components </a>
<a class="btn btn-primary" href="<%= $url %>source.tar.gz"> ZFSBootMenu Source </a>
<h2> Retrieve the latest ZFSBootMenu assets from the CLI</h2>
<h3> Release and recovery images</h3>
<pre>
curl <%= $url %>:asset/:build
asset => [ 'efi', 'components' ]
build => [ 'release', 'recovery' ]
</pre>
<h3> Other assets</h3>
<pre>
curl <%= $url %>:asset
asset => [ 'sha256.sig', 'sha256.txt', 'source', 'zbm-builder.sh', 'zbm-kcl' ]
</pre>
<h3> Save download as a custom file name </h3>
<pre>
$ wget <%= $url %>zfsbootmenu.EFI
$ curl -LO <%= $url %>zfsbootmenu.EFI
</pre>
<h3> Save download as named by the project </h3>
<pre>
$ wget --content-disposition <%= $url %>efi
$ curl -LJO <%= $url %>efi
</pre>
<h3> Download the recovery build instead of the release build </h3>
<pre>
$ wget --content-disposition <%= $url %>efi/recovery
$ curl -LJO <%= $url %>efi/recovery
</pre>
Refer to <a href="https://docs.zfsbootmenu.org/#signature-verification-and-prebuilt-efi-executables">docs.zfsbootmenu.org</a> for signature verification help.
</body>
</html>

@@ help.txt.ep
% my $url = url_for->to_abs->scheme('https');
Directly download the latest ZFSBootMenu assets 

# Retrieve the latest recovery or release assets from the CLI
# asset => [ 'efi', 'components' ]
# build => [ 'release', 'recovery' ]

$ curl <%= $url %>:asset/:build

# Retrieve additional assets from the CLI
# asset => [ 'sha256.sig', 'sha256.txt', 'source', 'zbm-builder.sh', 'zbm-kcl' ]

$ curl <%= $url %>:asset

# Save download as a custom file name

$ wget <%= $url %>zfsbootmenu.EFI
$ curl -LO <%= $url %>zfsbootmenu.EFI

# Save download as named by the project

$ wget --content-disposition <%= $url %>efi
$ curl -LJO <%= $url %>efi

# Download the recovery build instead of the release build
$ wget --content-disposition <%= $url %>efi/recovery
$ curl -LJO <%= $url %>efi/recovery

Refer to https://docs.zfsbootmenu.org/#signature-verification-and-prebuilt-efi-executables
