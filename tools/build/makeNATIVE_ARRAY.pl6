# This script reads the native_array.pm file from STDIN, and generates the
# intarray, numarray and strarray roles in it, and writes it to STDOUT.

use v6;

my $generator = $*PROGRAM-NAME;
my $generated = DateTime.now.gist.subst(/\.\d+/,'');
my $start     = '#- start of generated part of ';
my $idpos     = $start.chars;
my $idchars   = 3;
my $end       = '#- end of generated part of ';

# for all the lines in the source that don't need special handling
for $*IN.lines -> $line {

    # nothing to do yet
    unless $line.starts-with($start) {
        say $line;
        next;
    }

    # found shaped header, ignore
    my $type = $line.substr($idpos,$idchars);
    if $type eq 'sha' {
        say $line;
        next;
    }

    # found header
    die "Don't know how to handle $type" unless $type eq "int" | "num" | "str";
    say $start ~ $type ~ "array role -----------------------------------";
    say "#- Generated on $generated by $generator";
    say "#- PLEASE DON'T CHANGE ANYTHING BELOW THIS LINE";

    # skip the old version of the code
    for $*IN.lines -> $line {
        last if $line.starts-with($end);
    }

    # set up template values
    my %mapper =
      postfix => $type.substr(0,1),
      type    => $type,
      Type    => $type.tclc,
    ;

    # spurt the role
    say Q:to/SOURCE/.subst(/ '#' (\w+) '#' /, -> $/ { %mapper{$0} }, :g).chomp;

        multi method AT-POS(#type#array:D: int $idx) is raw {
            nqp::atposref_#postfix#(self, $idx)
        }
        multi method AT-POS(#type#array:D: Int:D $idx) is raw {
            nqp::atposref_#postfix#(self, $idx)
        }

        multi method ASSIGN-POS(#type#array:D: int $idx, #type# $value) {
            nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: Int:D $idx, #type# $value) {
            nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: int $idx, #Type#:D $value) {
            nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: Int:D $idx, #Type#:D $value) {
            nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: Any $idx, Mu \value) {
            X::TypeCheck.new(
                operation => "assignment to #type# array element #$idx",
                got       => value,
                expected  => T,
            ).throw;
        }

        multi method STORE(#type#array:D: $value) {
            nqp::setelems(self,1);
            nqp::bindpos_#postfix#(self, 0, nqp::unbox_#postfix#($value));
            self
        }
        multi method STORE(#type#array:D: #type# @values) {
            nqp::setelems(self,@values.elems);
            nqp::splice(self,@values,0,@values.elems)
        }
        multi method STORE(#type#array:D: @values) {
            my int $elems = @values.elems;
            nqp::setelems(self, $elems);

            my int $i = -1;
            nqp::bindpos_#postfix#(self, $i,
              nqp::unbox_#postfix#(@values.AT-POS($i)))
              while nqp::islt_i($i = nqp::add_i($i,1),$elems);
            self
        }

        multi method push(#type#array:D: #type# $value) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method push(#type#array:D: #Type#:D $value) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method push(#type#array:D: Mu \value) {
            X::TypeCheck.new(
                operation => 'push to #type# array',
                got       => value,
                expected  => T,
            ).throw;
        }
        multi method append(#type#array:D: #type# $value) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method append(#type#array:D: #Type#:D $value) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method append(#type#array:D: #type#array:D $values) is default {
            nqp::splice(self,$values,nqp::elems(self),0)
        }
        multi method append(#type#array:D: @values) {
            fail X::Cannot::Lazy.new(:action<append>, :what(self.^name))
              if @values.is-lazy;
            nqp::push_#postfix#(self, $_) for flat @values;
            self
        }

        method pop(#type#array:D: --> #type#) {
            nqp::elems(self) > 0
              ?? nqp::pop_#postfix#(self)
              !! die X::Cannot::Empty.new(:action<pop>, :what(self.^name));
        }

        method shift(#type#array:D: --> #type#) {
            nqp::elems(self) > 0
              ?? nqp::shift_#postfix#(self)
              !! die X::Cannot::Empty.new(:action<shift>, :what(self.^name));
        }

        multi method unshift(#type#array:D: #type# $value) {
            nqp::unshift_#postfix#(self, $value);
            self
        }
        multi method unshift(#type#array:D: #Type#:D $value) {
            nqp::unshift_#postfix#(self, $value);
            self
        }
        multi method unshift(#type#array:D: @values) {
            fail X::Cannot::Lazy.new(:action<unshift>, :what(self.^name))
              if @values.is-lazy;
            nqp::unshift_#postfix#(self, @values.pop) while @values;
            self
        }
        multi method unshift(#type#array:D: Mu \value) {
            X::TypeCheck.new(
                operation => 'unshift to #type# array',
                got       => value,
                expected  => T,
            ).throw;
        }

        multi method splice(#type#array:D: $offset=0, $size=Whatever, *@values) {
            fail X::Cannot::Lazy.new(:action('splice in'))
              if @values.is-lazy;

            my $elems = self.elems;
            my int $o = nqp::istype($offset,Callable)
              ?? $offset($elems)
              !! nqp::istype($offset,Whatever)
                ?? $elems
                !! $offset.Int;
            X::OutOfRange.new(
              :what('Offset argument to splice'),
              :got($o),
              :range("0..$elems"),
            ).fail if $o < 0 || $o > $elems; # one after list allowed for "push"

            my int $s = nqp::istype($size,Callable)
              ?? $size($elems - $o)
              !! !defined($size) || nqp::istype($size,Whatever)
                 ?? $elems - ($o min $elems)
                 !! $size.Int;
            X::OutOfRange.new(
              :what('Size argument to splice'),
              :got($s),
              :range("0..^{$elems - $o}"),
            ).fail if $s < 0;

            my @ret := nqp::create(self);
            my int $i = $o;
            my int $n = ($elems min $o + $s) - 1;
            while $i <= $n {
                nqp::push_#postfix#(@ret, nqp::atpos_#postfix#(self, $i));
                $i = $i + 1;
            }

            my @splicees := nqp::create(self);
            nqp::push_#postfix#(@splicees, @values.shift) while @values;
            nqp::splice(self, @splicees, $o, $s);
            @ret;
        }

        multi method min(#type#array:D:) {
            nqp::if(
              (my int $elems = self.elems),
              nqp::stmts(
                (my int $i),
                (my #type# $min = nqp::atpos_#postfix#(self,0)),
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::islt_#postfix#(nqp::atpos_#postfix#(self,$i),$min),
                    ($min = nqp::atpos_#postfix#(self,$i))
                  )
                ),
                $min
              ),
              Inf
            )
        }
        multi method max(#type#array:D:) {
            nqp::if(
              (my int $elems = self.elems),
              nqp::stmts(
                (my int $i),
                (my #type# $max = nqp::atpos_#postfix#(self,0)),
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::isgt_#postfix#(nqp::atpos_#postfix#(self,$i),$max),
                    ($max = nqp::atpos_#postfix#(self,$i))
                  )
                ),
                $max
              ),
              -Inf
            )
        }
        multi method minmax(#type#array:D:) {
            nqp::if(
              (my int $elems = self.elems),
              nqp::stmts(
                (my int $i),
                (my #type# $min =
                  my #type# $max = nqp::atpos_#postfix#(self,0)),
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::islt_#postfix#(nqp::atpos_#postfix#(self,$i),$min),
                    ($min = nqp::atpos_#postfix#(self,$i)),
                    nqp::if(
                      nqp::isgt_#postfix#(nqp::atpos_#postfix#(self,$i),$max),
                      ($max = nqp::atpos_#postfix#(self,$i))
                    )
                  )
                ),
                Range.new($min,$max)
              ),
              Range.new(Inf,-Inf)
            )
        }

        method iterator(#type#array:D:) {
            class :: does Iterator {
                has int $!i;
                has $!array;    # Native array we're iterating

                method !SET-SELF(\array) {
                    $!array := nqp::decont(array);
                    $!i = -1;
                    self
                }
                method new(\array) { nqp::create(self)!SET-SELF(array) }

                method pull-one() is raw {
                    ($!i = $!i + 1) < nqp::elems($!array)
                      ?? nqp::atposref_#postfix#($!array,$!i)
                      !! IterationEnd
                }
                method push-all($target --> IterationEnd) {
                    my int $i     = $!i;
                    my int $elems = nqp::elems($!array);
                    $target.push(nqp::atposref_#postfix#($!array,$i))
                      while ($i = $i + 1) < $elems;
                    $!i = $i;
                }
            }.new(self)
        }
        method reverse(#type#array:D:) is nodal {
            nqp::stmts(
              (my int $elems = nqp::elems(self)),
              (my int $last  = nqp::sub_i($elems,1)),
              (my int $i     = -1),
              (my $to := nqp::clone(self)),
              nqp::while(
                nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                nqp::bindpos_#postfix#($to,nqp::sub_i($last,$i),
                  nqp::atpos_#postfix#(self,$i))
              ),
              $to
            )
        }
        method rotate(#type#array:D: Int(Cool) $rotate = 1) is nodal {
            nqp::stmts(
              (my int $elems = nqp::elems(self)),
              (my $to := nqp::clone(self)),
              (my int $i = -1),
              (my int $j =
                nqp::mod_i(nqp::sub_i(nqp::sub_i($elems,1),$rotate),$elems)),
              nqp::if(nqp::islt_i($j,0),($j = nqp::add_i($j,$elems))),
              nqp::while(
                nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                nqp::bindpos_#postfix#(
                  $to,
                  ($j = nqp::mod_i(nqp::add_i($j,1),$elems)),
                  nqp::atpos_#postfix#(self,$i)
                ),
              ),
              $to
            )
        }
        multi method sort(#type#array:D:) {
            Rakudo::Sorting.MERGESORT-#type#(nqp::clone(self))
        }
SOURCE

    # we're done for this role
    say "#- PLEASE DON'T CHANGE ANYTHING ABOVE THIS LINE";
    say $end ~ $type ~ "array role -------------------------------------";
}
