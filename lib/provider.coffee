module.exports =
  selector: '.source.tts.lua'
  disableForSelector: '.source.tts.lua .comment'
  filterSuggestions: true

  # This will take priority over the default provider, which has a priority of 0.
  # `excludeLowerPriority` will suppress any providers with a lower priority
  # i.e. The default provider will be suppressed
  inclusionPriority: 2
  excludeLowerPriority: true

  getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix}) ->
    new Promise (resolve) ->
      # Find your suggestions here
      suggestions = []

      # Substring up until this position
      line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])

      # Hacks. Make Lua nicer.
      if atom.config.get('tabletopsimulator-lua.hacks.incrementals') != 'off'
        matches = line.match(/^\s*([\w.:\[\]"'#]+)(\s*)([-+*\u002f])=(\s*)(.*)$/)
        if matches
          identifier = matches[1]
          spacing    = matches[2]
          if spacing == '' and atom.config.get('tabletopsimulator-lua.hacks.incrementals') == 'spaced'
            spacing = ' '
          operator   = matches[3]
          postfix    = matches[5]
          #if postfix != ''
          #  postfix += '\n'
          resolve([{
            snippet: spacing + '=' + spacing + identifier + spacing + operator + spacing + postfix + '$1'
            displayText: '=' + spacing + identifier + spacing + operator + spacing + postfix
            replacementPrefix: matches[2] + matches[3] + '=' + matches[4] + matches[5]
            neverFilter: true
          }])
          return

      #console.log scopeDescriptor.scopes[1]
      if scopeDescriptor.scopes[1] == "keyword.operator.lua" || scopeDescriptor.scopes[1] == "string.quoted.double.lua" || scopeDescriptor.scopes[1] == "string.quoted.single.lua"
        resolve([])
        return

      # Are we in the global script or an object script?
      global_script = editor.getPath().endsWith('-1.ttslua')

      # Split line into bracket depths
      depths = {}
      depth = 0
      depths[depth] = ""
      returned_to_depth = ""
      returning_from = ""
      bracket_lookup = {"]":"[]", "}":"{}", ")":"()"}
      for c in line
        if c.match(/[\(\{\[]/) #open bracket
            depth += 1
            if depth of depths
              returned_to_depth = true
              returning_from = " "
            else
              depths[depth] = ""
        else if c.match(/[\)\}\]]/) #close bracket
            depth -= 1
            if depth of depths
              returned_to_depth = true
              returning_from = bracket_lookup[c]
            else
              depths[depth] = ""
        else
          if returned_to_depth
            depths[depth] += returning_from   #indicator of where we just were
            returned_to_depth = false
          depths[depth] += c
      depths[depth] += returning_from

      # Split relevant depth into tokens
      tokens = depths[depth].split(".")
      this_token = ""           # user is currently typing
      this_token_intact = true  # is it just alphanumerics?
      previous_token = ""       # last string before a '.'
      previous_token_2 = ""     # ...and the one before that
      if tokens.length > 0
        this_token = tokens.slice(-1)[0]
        if this_token.match(/[^a-zA-Z0-9_]+/)
          this_token_intact = false
        if tokens.length > 1
          for part in tokens.slice(-2)[0].split(/[^a-zA-Z0-9_\[\]\{\}\(\)]+/).reverse() #find the last alphanumeric string
            if part != ""
              previous_token = part
              break
          if tokens.length > 2
            for part in tokens.slice(-3)[0].split(/[^a-zA-Z0-9_\[\]\{\}\(\)]+/).reverse()
              if part != ""
                previous_token_2 = part
                break

      #console.log tokens
      #console.log this_token, "(", this_token_intact, ") <- ", previous_token, " <- ", previous_token_2

      if prefix == "." and previous_token.match(/^[0-9]$/)
        # If we're in the middle of typing a number then suggest nothing on .
        resolve([])
        return
      else if (line.match(/(^|\s)else$/) || line.match(/(^|\s)elseif$/) || line.match(/(^|\s)end$/) || line == "end")
        # Short circuit some common lua keywords
        resolve([])
        return

      # Section: Control blocks
      if (line.endsWith(" do"))
        suggestions = [
          {
            snippet: 'do\n\t$1\nend'
            displayText: 'do...end'
          },
        ]
      else if (line.endsWith(" then") and not line.includes("elseif"))
        suggestions = [
          {
            snippet: 'then\n\t$1\nend'
            displayText: 'then...end'
          },
        ]
      else if (line.endsWith(" repeat"))
        suggestions = [
          {
            snippet: 'repeat\n\t$1\nuntil $2'
            displayText: 'repeat...until'
          },
        ]
      else if (line.includes("function") && line.endsWith(")"))
        function_name = this_token.substring(0, this_token.lastIndexOf("("))
        function_name = function_name.substring(function_name.lastIndexOf(" ") + 1)
        function_name = function_name + atom.config.get('tabletopsimulator-lua.style.coroutinePostfix')
        suggestions = [
          {
            snippet: '\n\t$1\nend'
            displayText: 'function...end'
          },
          {
            snippet: '\n\tfunction ' + function_name + "()\n\t\t$1\n\t\treturn 1\n\tend\n\tstartLuaCoroutine(self, '" + function_name + "')\nend"
            displayText: 'function...coroutine...end'
          },
          {
            snippet: '\n\tfunction ' + function_name + "()\n\t\trepeat\n\t\t\tcoroutine.yield(0)\n\t\tuntil $1\n\t\treturn 1\n\tend\n\tstartLuaCoroutine(self, '" + function_name + "')\nend"
            displayText: 'function...coroutine...repeat...end'
          },
        ]

      # Done!
      resolve(suggestions)


# Replacement patterns for autocomplete parameters
parameter_patterns = {
  'type': '$${$1:$2}',
  'name': '$${$1:$3}',
  'both': '$${$1:$2_$3}',
  'none': '$${$1:}',
}

# First letter to caps
capitalize = (s) ->
  return s.substring(0,1).toUpperCase() + s.substring(1)
