.namespace []
.sub '!find_contextual'
    .param string name

    # first search caller scopes
    $P0 = find_dynamic_lex name
    unless null $P0 goto done

    # next, strip twigil and search PROCESS package
    .local string pkgname
    $S0 = substr name, 0, 1
    $S1 = substr name, 2
    pkgname = concat $S0, $S1
    $P0 = get_hll_global ['PROCESS'], pkgname
    unless null $P0 goto done
    $P0 = get_global pkgname
    unless null $P0 goto done

  fail:
    $P0 = '!FAIL'('Contextual ', name, ' not found')
  done:
    .return ($P0)
.end
