package Test::Regexp::Pattern;

# DATE
# VERSION

use 5.010001;
use strict 'subs', 'vars';
use warnings;

use File::Spec;
use Test::Builder;

my $Test = Test::Builder->new;

sub import {
    my $self = shift;
    my $caller = caller;
    no strict 'refs';
    *{$caller.'::regexp_patterns_in_module_ok'}      = \&regexp_patterns_in_module_ok;
    *{$caller.'::regexp_patterns_in_all_modules_ok'} = \&regexp_patterns_in_all_modules_ok;

    $Test->exported_to($caller);
    $Test->plan(@_);
}

sub _test_regexp_pattern {
    my ($re, $opts) = @_;
    my $ok = 1;

  GENERAL: {
        $Test->ok(($re->{pat} xor $re->{gen}), "Must declare pat OR gen but not both") or $ok = 0;
    }

  EXAMPLES: {
        last unless $opts->{test_examples} && $re->{examples};
        my $i = 0;
        for my $eg (@{ $re->{examples} }) {
            $i++;
            next unless $eg->{test} // 1;
            $Test->subtest(
                "example #$i" .
                    ($eg->{name} ? " ($eg->{name})" :
                     ($eg->{summary} ? " ($eg->{summary})" : "")),
                sub {
                    $Test->ok(defined($eg->{str}), 'example provides string to match') or do {
                        $ok = 0;
                        next EXAMPLE;
                    };
                    my $pat;
                    if ($eg->{gen_args}) {
                        $pat = $re->{gen}->(%{ $eg->{gen_args} });
                    } else {
                        $pat = $re->{pat};
                    }
                    my $actual_match = $eg->{str} =~ $pat ? 1:0;
                    if (ref $eg->{matches} eq 'ARRAY') {
                        my $len = @{ $eg->{matches} };
                        my @actual_matches;
                        for (1..$len) {
                            push @actual_matches, ${$_};
                        }
                        my $should_match = $len ? 1:0;
                        if ($should_match) {
                            $Test->ok( $actual_match, 'string should match') or do {
                                $ok = 0;
                                next EXAMPLE;
                            };
                            Test::More::is_deeply(\@actual_matches, $eg->{matches}, 'matches') or do {
                                  $Test->diag($Test->explain(\@actual_matches));
                                  $ok = 0;
                              };
                        } else {
                            $Test->ok(!$actual_match, 'string should not match') or do {
                                $ok = 0;
                                next EXAMPLE;
                            };
                        }
                    } elsif (ref $eg->{matches} eq 'HASH') {
                        my %actual_matches = %+;
                        my $should_match = %{ $eg->{matches} } ? 1:0;
                        if ($should_match) {
                            $Test->ok( $actual_match, 'string should match') or do {
                                $ok = 0;
                                next EXAMPLE;
                            };
                            Test::More::is_deeply(\%actual_matches, $eg->{matches}, 'matches') or do {
                                  $Test->diag($Test->explain(\%actual_matches));
                                  $ok = 0;
                              };
                        } else {
                            $Test->ok(!$actual_match, 'string should not match') or do {
                                $ok = 0;
                                next EXAMPLE;
                            };
                        }
                    } else {
                        if ($eg->{matches}) {
                            $Test->ok( $actual_match, 'string should match') or do {
                                $ok = 0;
                                next EXAMPLE;
                            };
                        } else {
                            $Test->ok(!$actual_match, 'string should not match') or do {
                                $ok = 0;
                                next EXAMPLE;
                            };
                        }
                    }
                }) or $ok = 0;
        }
    }
    $ok;
}

sub regexp_patterns_in_module_ok {
    my $module = shift;
    my %opts = (@_ && (ref $_[0] eq "HASH")) ? %{(shift)} : ();
    my $msg  = @_ ? shift : "Regexp patterns in module $module";
    my $res;
    my $ok = 1;

    $opts{test_examples}  //= 1;

    my $has_tests;

    $Test->subtest(
        $msg,
        sub {
            (my $modulepm = "$module.pm") =~ s!::!/!g;
            require $modulepm;

            for my $name (sort keys %{ "$module\::RE" }) {
                my $re = ${"$module\::RE"}{$name};
                $has_tests++;
                $Test->subtest(
                    "pattern $name",
                    sub {
                        _test_regexp_pattern($re, \%opts) or $ok = 0;
                    },
                ) or $ok = 0;
            }
            unless ($has_tests) {
                $Test->ok(1);
                $Test->diag("No regexp patterns to test");
            }
        } # subtest
    ) or $ok = 0;

    $ok;
}

# BEGIN copy-pasted from Test::Pod::Coverage, with a bit modification

sub all_modules {
    my @starters = @_ ? @_ : _starting_points();
    my %starters = map {$_,1} @starters;

    my @queue = @starters;

    my @modules;
    while ( @queue ) {
        my $file = shift @queue;
        if ( -d $file ) {
            local *DH;
            opendir DH, $file or next;
            my @newfiles = readdir DH;
            closedir DH;

            @newfiles = File::Spec->no_upwards( @newfiles );
            @newfiles = grep { $_ ne "CVS" && $_ ne ".svn" } @newfiles;

            push @queue, map "$file/$_", @newfiles;
        }
        if ( -f $file ) {
            next unless $file =~ /\.pm$/;

            my @parts = File::Spec->splitdir( $file );
            shift @parts if @parts && exists $starters{$parts[0]};
            shift @parts if @parts && $parts[0] eq "lib";
            $parts[-1] =~ s/\.pm$// if @parts;

            # Untaint the parts
            for ( @parts ) {
                if ( /^([a-zA-Z0-9_\.\-]*)$/ && ($_ eq $1) ) {
                    $_ = $1;  # Untaint the original
                }
                else {
                    die qq{Invalid and untaintable filename "$file"!};
                }
            }
            my $module = join( "::", grep {length} @parts );
            push( @modules, $module );
        }
    } # while

    return @modules;
}

sub _starting_points {
    return 'blib' if -e 'blib';
    return 'lib';
}

# END copy-pasted from Test::Pod::Coverage

sub regexp_patterns_in_all_modules_ok {
    my $opts = (@_ && (ref $_[0] eq "HASH")) ? shift : {};
    my $msg  = shift;
    my $ok = 1;

    my @starters = _starting_points();
    local @INC = (@starters, @INC);

    $Test->plan(tests => 1);

    my @modules = all_modules(@starters);
    if (@modules) {
        $Test->subtest(
            "Regexp patterns on all dist's modules",
            sub {
                for my $module (@modules) {
                    my $thismsg = defined $msg ? $msg :
                        "Regexp patterns in module $module";
                    my $thisok = regexp_patterns_in_module_ok(
                        $module, $opts, $thismsg)
                        or $ok = 0;
                }
            }
        ) or $ok = 0;
    } else {
        $Test->ok(1, "No modules found.");
    }
    $ok;
}

1;
# ABSTRACT: Test Regexp::Pattern patterns

=for Pod::Coverage ^(all_modules)$

=head1 SYNOPSIS

To check all regexp patterns in a module:

 use Test::Regexp::Patterns tests=>1;
 regexp_patterns_in_module_ok("Foo::Bar", {opt => ...}, $msg);

Alternatively, you can check all regexp patterns in all modules in a distro:

 # save in release-regexp-pattern.t, put in distro's t/ subdirectory
 use Test::More;
 plan skip_all => "Not release testing" unless $ENV{RELEASE_TESTING};
 eval "use Test::Regexp::Pattern";
 plan skip_all => "Test::Regexp::Pattern required for testing Regexp::Pattern patterns" if $@;
 regexp_patterns_in_all_modules_ok({opt => ...}, $msg);


=head1 DESCRIPTION

This module performs various checks on a module's L<Regexp::Pattern> patterns.
It is recommended that you include something like C<release-regexp-pattern.t> in
your distribution if you add regexp patterns to your code. If you use
L<Dist::Zilla> to build your distribution, there is
L<[Test::Regexp::Pattern]|Dist::Zilla::Plugin::Test::Regexp::Pattern> to make it
easy to do so.


=head1 FUNCTIONS

All these functions are exported by default.

=head2 regexp_patterns_in_module_ok($module [, \%opts ] [, $msg])

Load C<$module> and perform test for regexp patterns (C<%RE>) in the module.

Available options:

=over 4

=item * test_examples => bool (default: 1)

=back

=head2 regexp_patterns_in_all_modules_ok([ \%opts ] [, $msg])

Look for modules in directory C<lib> (or C<blib> instead, if it exists), and run
C<regexp_patterns_in_module_ok()> against each of them.

Options are the same as in C<regexp_patterns_in_module_ok()>.


=head1 ACKNOWLEDGEMENTS

Some code taken from L<Test::Pod::Coverage> by Andy Lester.


=head1 SEE ALSO

L<test-regexp-pattern>, a command-line interface for
C<regexp_patterns_in_all_modules_ok()>.

L<Regexp::Pattern>

L<Dist::Zilla::Plugin::Test::Regexp::Pattern>

=cut
