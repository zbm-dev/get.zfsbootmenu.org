#!perl

use strict;
use warnings;

use Mojolicious::Lite -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);
use Mojo::File;

use Data::Dumper;

any ['GET', 'POST'] => '/#asset/#build' => {build => 'release'} => sub ($c) {
  my @rassets;
  my $ua  = Mojo::UserAgent->new;
  my $res = $ua->get('https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest')->result;

  unless ( $res->is_success ) {
    return $c->render( text => "Unable to retrieve asset list from api.github.com", status => '200' );
  }
  my $releases = decode_json( $res->body );

  foreach my $rasset ( @{ $releases->{'assets'} } ) {
    push( @rassets, $rasset->{browser_download_url} );
  }

  if ( !@rassets ) {
    return $c->render( text => "Unable to retrieve asset list from api.github.com", status => '200' );
  }

  print Dumper($c);

  my $asset = $c->param('asset');

  # There are no build styles for sha256.txt|sig
  if ( $asset =~ m/(sha256|txt|sig)/ ) {
    foreach my $rasset (@rassets) {
      my $rfile = ( split( '/', $rasset ) )[-1];
      if ( $rfile =~ m/\Q$asset/i ) {
        return $c->redirect_to($rasset);
      }
    }
  }

  my $build = $c->param('build');
  my ( $file, $type ) = split( /\./, $asset );

  my $found_asset;

  # Match against the full filename
  foreach my $rasset (@rassets) {
    my $rfile = ( split( '/', $rasset ) )[-1];
    if ( $rfile =~ m/\Q$asset/i and $rfile =~ m/\Q$build/i ) {
      $found_asset = $rasset;
      last;
    }
  }

  if ( defined $type ) {
    foreach my $rasset (@rassets) {
      my $rfile = ( split( '/', $rasset ) )[-1];
      if ( $rfile =~ m/\Q$type/i and $rfile =~ m/\Q$build/i ) {
        $found_asset = $rasset;
        last;
      }
    }
  }

  if ( defined $file ) {
    foreach my $rasset (@rassets) {
      my $rfile = ( split( '/', $rasset ) )[-1];
      if ( $rfile =~ m/\Q$file/i and $rfile =~ m/\Q$build/i ) {
        $found_asset = $rasset;
        last;
      }
    }
  }

  unless (defined $found_asset) {
    return $c->render( text => "No matches found for $asset", status => '200' );
  }

  if ( ($asset =~ m/efi/i) and ( defined $c->param('kcl')) ) {
    $res = $ua->max_redirects(5)->get($found_asset)->result;
    my $download = $res->content->asset->path;

    my $tmp = Mojo::File->new(File::Temp->new);
    my $tmp_path = $tmp->to_string;

    my @output = qx(objcopy --remove-section .cmdline $download $tmp_path);

    my $tmp_kcl = Mojo::File->new(File::Temp->new);
    $tmp_kcl->spurt($c->param('kcl'));
    my $tmp_kcl_path = $tmp_kcl->to_string;

    @output = qx(objcopy --add-section .cmdline=$tmp_kcl_path --change-section-vma .cmdline=0x3000 $tmp_path);
    my $filename = (split('/', $found_asset))[-1];
    $c->res->headers->content_disposition("attachment; filename=$filename;");
    $c->reply->file($tmp_path);
  } else {
    return $c->redirect_to($found_asset);
  }
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

#plugin SetUserGroup => { user => "nobody", group => "nogroup" };
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

<h2> Generate custom ZFSBootMenu EFI asset </h2>
<form class="form-inline" method="POST" action="/efi/release" id="kcl">
<div class="form-group kcl">
<label for="kcl">Kernel Command Line</label>
<input type="text" class="form-control" name="kcl" id="kcl" placeholder="zfsbootmenu loglevel=4 nomodeset">
</div>
<button type="submit" class="btn btn-primary embed-kcl">Generate!</button>
</form>
<h2> Retrieve the latest ZFSBootMenu assets from the CLI</h2>
<pre>
curl https://get.zfsbootmenu.org/:asset/:build
asset => [ 'efi', 'tar.gz', 'sha256.sig', 'sha256.txt' ]
build => [ 'release', 'recovery' ]
</pre>
<h3> Save download as a custom file name </h3>
<pre>
$ wget https://get.zfsbootmenu.org/zfsbootmenu.EFI
$ curl -LO https://get.zfsbootmenu.org/zfsbootmenu.EFI
</pre>
<h3> Save download as named by the project </h3>
<pre>
$ wget --content-disposition https://get.zfsbootmenu.org/efi
$ curl -LJO https://get.zfsbootmenu.org/efi
</pre>
<h3> Download the recovery build instead of the release build </h3>
<pre>
$ wget --content-disposition https://get.zfsbootmenu.org/efi/recovery
$ curl -LJO https://get.zfsbootmenu.org/efi/recovery
</pre>
Refer to <a href="https://github.com/zbm-dev/zfsbootmenu#signature-verification-and-prebuilt-efi-executables">zbm-dev/zfsbootmenu</a> for signature verification help.
</body>
</html>

@@ help.txt.ep
Directly download the latest ZFSBootMenu assets

# Retrieve the latest ZFSBootMenu assets from the CLI
# asset => [ 'efi', 'tar.gz', 'sha256.sig', 'sha256.txt' ]
# build => [ 'release', 'recovery' ]

$ curl https://get.zfsbootmenu.org/:asset/:build

# Save download as a custom file name

$ wget https://get.zfsbootmenu.org/zfsbootmenu.EFI
$ curl -LO https://get.zfsbootmenu.org/zfsbootmenu.EFI

# Save download as named by the project

$ wget --content-disposition https://get.zfsbootmenu.org/efi
$ curl -LJO https://get.zfsbootmenu.org/efi

# Download the recovery build instead of the release build
$ wget --content-disposition https://get.zfsbootmenu.org/efi/recovery
$ curl -LJO https://get.zfsbootmenu.org/efi/recovery

Refer to https://github.com/zbm-dev/zfsbootmenu#signature-verification-and-prebuilt-efi-executables
