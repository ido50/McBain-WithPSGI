package McBain::WithPSGI;

# ABSTRACT: Load a McBain API as a RESTful PSGI web service

use warnings;
use strict;
use parent 'Plack::Component';

use Carp;
use JSON::MaybeXS qw/JSON/;
use Plack::Request;
use Try::Tiny;

our $VERSION = "3.000000";
$VERSION = eval $VERSION;

my $json = JSON->new->utf8->allow_blessed->convert_blessed;

sub new {
	my ($class, $api) = @_;

	bless { api => $api }, $class;
}

sub call {
	my ($self, $psgi_env) = @_;

	my $req = Plack::Request->new($psgi_env);

	my $payload = $req->content ? $json->decode($req->content) : {};

	# also take parameters from query string, if any
	# and let them have precedence over request content
	my $query = $req->query_parameters->mixed;
	foreach (keys %$query) {
		$payload->{$_} = $query->{$_};
	}

	try {
		my $res = $self->{api}->call($req->method.':'.$req->path, $payload, __PACKAGE__, $psgi_env);
		$res = { $req->method.':'.$req->path => $res }
			unless ref $res eq 'HASH';

		my @headers = ('Content-Type' => 'application/json; charset=UTF-8');

		if ($req->method eq 'OPTIONS') {
			push(@headers, 'Allow' => join(',', keys %$res));
		}

		return [
			200,
			\@headers,
			[$json->encode($res)]
		];
	} catch {
		$_ = { code => 500, error => $_ }
			unless ref $_;

		return [
			delete($_->{code}),
			['Content-Type' => 'application/json; charset=UTF-8'],
			[$json->encode($_)]
		];
	};
}

1;
__END__
