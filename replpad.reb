;
; File: %replpad.reb
; Summary: "Read-Eval-Print-Loop implementation and JavaScript interop"
; Project: "JavaScript REPLpad for Ren-C branch of Rebol 3"
; Homepage: https://github.com/hostilefork/replpad-js/
;
; Copyright (c) 2018-2019 hostilefork.com
;
; See README.md and CREDITS.md for more information
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU Affero General Public License as
; published by the Free Software Foundation, either version 3 of the
; License, or (at your option) any later version.
;
; https://www.gnu.org/licenses/agpl-3.0.en.html
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU Affero General Public License for more details.
;


!!: js-native [
    {Temporary debug helper, sends to browser console log instead of replpad}
    message
]{
    console.log(
        "@" + reb.Tick() + ": "
        + reb.Spell("form", reb.R(reb.Arg('message')))
    )
}


replpad-reset: js-awaiter [
    {Clear contents of the browser window}
]{
    replpad.innerHTML = ""

    // !!! This used to say:
    //
    // "The output strategy is to merge content into the last div, until
    // a newline is seen.  Kick it off with an empty div, so there's
    // always somewhere the first output can stick to."
    //
    // But that was leaving a blank line before the first output note, so the
    // note wasn't at the top of the screen.  Leaving it out seems to work;
    // review invariants.
    //
    /* replpad.innerHTML = "<div class='line'>&zwnj;</div>" */

    setTimeout(resolve, 0)  // yield to browser to see result synchronously
}


replpad-write: js-awaiter [
    {Print a string of text to the REPLPAD (no newline)}
    param [text!]
    /note "Format with CSS yellow sticky-note class"
    /html
]{
    let param = reb.Spell(reb.ArgR('param'))
    let note = reb.Did(reb.ArgR('note'))
    let html = reb.Did(reb.ArgR('html'))

    // If not /HTML and just code, for now assume that any TAG-like things
    // should not be interpreted by the browser.  So escape--but do so using
    // the browser's internal mechanisms.
    //
    // https://stackoverflow.com/q/6234773/
    //
    if (!html) {
        let escaper = document.createElement('p')
        escaper.innerText = param  // assignable property, assumes literal text
        param = escaper.innerHTML  // so <my-tag> now becomes &lt;my-tag&gt;
    }

    if (note) {
        replpad.appendChild(load(
            "<div class='note'><p>"
            + param  // not escaped, so any TAG!-like things are HTML
            + "</p><div>"
        ))
        replpad.appendChild(
            load("<div class='line'>&zwnj;</div>")
        )
        setTimeout(resolve, 0)  // yield to browser to see result synchronously
        return
    }

    let line = replpad.lastChild

    // Split string into pieces.  Note that splitting a string of just "\n"
    // will give ["", ""].
    //
    // Each newline means making a new div, but if there's no newline (e.g.
    // only "one piece") then no divs will be added.
    //
    let pieces = param.split("\n")
    line.innerHTML += pieces.shift()  // shift() takes first element
    while (pieces.length)
        replpad.appendChild(
            load("<div class='line'>&zwnj;" + pieces.shift() + "</div>")
        )

    setTimeout(resolve, 0)  // yield to browser to see result synchronously
}

lib/write-stdout: write-stdout: function [
    {Writes just text to the ReplPad}
    text [text! char!]
][
    if char? text [text: my to-text]
    replpad-write text
]

lib/print: print: function [
    {Helper that writes data and a newline to the ReplPad}
    line [<blank> text! block! char!]
    /html
][
    if char? line [
        if line <> newline [fail "PRINT only supports CHAR! of newline"]
        return write-stdout newline
    ]

    (write-stdout/(html) try spaced line) then [write-stdout newline]
]


lib/input: input: js-awaiter [
    {Read single-line or multi-line input from the user}
    return: [text!]
]{
    // !!! It seems that an empty div with contenteditable will stick
    // the cursor to the beginning of the previous div.  :-/  This does
    // not happen when the .input CSS class has `display: inline-block;`,
    // but then that prevents the div from flowing naturally along with
    // the previous divs...it jumps to its own line if it's too long.
    // Putting a (Z)ero (W)idth (N)on-(J)oiner before it seems to solve
    // the issue, so the cursor will jump to that when the input is empty.
    //
    replpad.lastChild.appendChild(load("&zwnj;"))

    let new_input = load("<div class='input'></div>")
    replpad.lastChild.appendChild(new_input)

    ActivateInput(new_input)

    // This body of JavaScript ending isn't enough to return to the Rebol
    // that called REPLPAD-INPUT.  The resolve function must be invoked by
    // JavaScript.  We save it in a global variable so that the page's event
    // callbacks dealing with input can call it when input is finished.
    //
    input_resolve = resolve
}


lib/wait: wait: js-awaiter [
    {Sleep for the requested number of seconds}
    seconds [integer! decimal!]
]{
    setTimeout(resolve, 1000 * reb.UnboxDecimal(reb.ArgR("seconds")))
}


lib/write: write: function [
    source [any-value!]
    data [any-value!]
][
    fail 'source [
        {WRITE is not supported in the web console yet, due to the browser's}
        {imposition of a security model (e.g. no local filesystem access).}
        {Features may be added in a more limited sense, for doing HTTP POST}
        {in form submissions.  Get involved if you know how!}
    ]
]


github-read: js-awaiter [
    owner [text!]
    repo [text!]
    branch [text!]
    path [text!]  ; FILE! ?  Require leading slash?
]{
    let owner = reb.Spell(reb.ArgR("owner"))
    let repo = reb.Spell(reb.ArgR("repo"))
    let branch = reb.Spell(reb.ArgR("branch"))
    if (branch != "master")
        console.error("!!! API handling for non-master branch needed")
    let path = reb.Spell(reb.ArgR("path"))

    let url = "https://api.github.com/repos/" + owner + "/" + repo
        + "/contents" + path

    console.log("Fetching GitHub file: " + url)

    let response = await fetch(url)

    // https://www.tjvantoll.com/2015/09/13/fetch-and-errors/
    if (!response.ok)
        throw Error(response.statusText)  // handled by .catch() below

    let json = await response.json()

    // GitHub gives back Base64 in JSON envelope

    resolve(function () {
        return reb.Run("debase/base", reb.T(json.content), reb.I(64))
    })  // if using emterpreter, need callback to use APIs in resolve()
}


file-read-text: js-awaiter [
    return: [text!]
    location [file!]
]{
    let location = reb.Spell(reb.ArgR("location"))

    let response = await fetch(location)  // can be relative

    // https://www.tjvantoll.com/2015/09/13/fetch-and-errors/
    if (!response.ok)
        throw Error(response.statusText)

    let text = await response.text()

    resolve(function () {
        return reb.Text(text)
    })  // if using emterpreter, need callback to use APIs in resolve()
}


lib/read: read: function [
    source [any-value!]
    /string
][
    if url? source [
        parse source [
            "https://github.com/"
                copy owner: to "/" skip
                copy repo: to "/" skip
                "blob/"
                copy branch: to "/"
                copy path: to end  ; include the leading /
        ] else [
            fail 'source [
                {There are strict limitations on web browsers being able to}
                {request URLs.  For the moment, READ works on a GitHub "blob"}
                {URL only, using CORS.  https://enable-cors.org/}
            ]
        ]

        data: github-read owner repo branch path
        return either string [as text! data] [data]
    ]

    if file? source [
        if not string [
            fail {ArrayBuffer binary READ of BINARY! not yet implemented}
        ]
        return file-read-text source
    ]

    fail 'source [{Cannot READ value of type} mold type of source]
]


hijack 'do adapt copy :do [
    ;
    ; !!! DO expects to be able to read source as BINARY!, but that feature is
    ; not yet implemented as it would depend on an API entry point that took
    ; a JS ArrayBuffer to build a binary out of.  Force read as TEXT!
    ;
    if file? :source [
        source: read/string source
    ]
]


lib/browse: browse: function [
    {Provide a clickable link to the user to open in the browser}
    url [url!]
][
    comment {
        // !!! This is how we would open a window in a JS-AWAITER, but it will
        // say popups are blocked.  The user has to configure accepting those,
        // or click on the link we give them.
        //
        // https://stackoverflow.com/a/11384018/
        //
        let url = reb.Spell(rebArgR('url'))

        if (false) {
            let win = window.open(url, '_blank');
            win.focus();
        }
    }

    ; Our alternative is we give a link in the console they can click.  Not
    ; very useful if they typed BROWSE literally, but if a command tried to
    ; open a window it's the sort of thing that would give them an option.
    ;
    replpad-write/html unspaced [
        {Click here: <a href="} url {" target="_blank">} url {</a>}
    ]
]


js-watch-visible: js-awaiter [
    visible [logic!]
]{
    let visible = reb.Did(reb.R(reb.Arg('visible')))

    let right_div = document.getElementById('right')

    // Suggestion from author of split.js is destroy/recreate to hide/show
    // https://github.com/nathancahill/Split.js/issues/120#issuecomment-428050178
    //
    if (visible) {
        if (!splitter) {
            replcontainer.classList.add("split-horizontal")
            right_div.style.display = 'block'
            splitter = Split(['#replcontainer', '#right'], {
                sizes: splitter_sizes,
                minSize: 200
            })
        }
    }
    else {
        // While destroying the splitter, remember the size ratios so that the
        // watchlist comes up the same percent of the screen when shown again.
        //
        if (splitter) {
            replcontainer.classList.remove("split-horizontal")
            splitter_sizes = splitter.getSizes()
            right_div.style.display = 'none'
            splitter.destroy()
            splitter = undefined
        }
    }

    setTimeout(resolve, 0)
}

watch: function [
    :arg [
        word! get-word! path! get-path!
        block! group!
        integer! tag! refinement!
    ]
        {word to watch or other legal parameter, see documentation)}
][
    ; REFINEMENT!s are treated as instructions.  `watch /on` seems easy...
    ;
    switch arg [
        /on [js-watch-visible true]
        /off [js-watch-visible false]

        fail ["Bad command:" arg]
    ]
]

; !!! The ABOUT command was not made part of the console extension, since
; non-console builds might want to be able to ask it from the command line.
; But it was put in HOST-START and not the mezzanine/help in general.  This
; needs to be rethought, but including ABOUT doing *something* since it is
; mentioned when the console starts up.
;
about: does [
    print [
        {This Rebol is running completely in your browser!  The evaluations}
        {aren't being sent to a remote server--the interpreter is client side!}
        newline newline

        {Please don't hesitate to submit any improvements, no matter how}
        {small...and come join the discussion on the forum and chat!}
    ]
]

; We don't want a deep stack when reporting errors or running user code.  So
; a reb.Promise("main") is run.
;
; !!! Has to be an ADAPT of CONSOLE, for some reason--investigate:
; https://github.com/hostilefork/replpad-js/issues/10
;
main: adapt 'console [
    !! "MAIN executing (this should show in browser console log)"

    replpad-reset

    replpad-git: https://github.com/hostilefork/replpad-js/blob/master/replpad.reb
    console-git: https://github.com/metaeducation/ren-c/blob/master/src/extensions/console/ext-console-init.reb
    chat: https://chat.stackoverflow.com/rooms/291/rebol
    forum: https://forum.rebol.info

    link: [href label] => [
        unspaced [{<a href="} href {" target="_blank">} label {</a>}]
    ]

    replpad-write/note/html spaced [
        {<b><i>Guess what...</i></b> this REPL is actually written in Rebol!}
        {Check out the} (link replpad-git {bridge to JavaScript})
        {as well as the} unspaced [(link console-git {Console Module}) "."]

        {While the techniques are still in early development, they show a}
        {lot of promise for JavaScript/Rebol interoperability.}

        {Discuss it on} (link chat {StackOverflow chat})
        {or join the} unspaced [(link forum {Discourse forum}) "."]

        {<br><br>}

        {<i>(Note: SHIFT-ENTER to type in multi-line code, Ctrl-Z to undo)</i>}
    ]

    ; Fall through to normal CONSOLE loop handling
]

; red text
fred: func [txt /newln][
    REPLPAD-WRITE/HTML unspaced [<font color=red> txt </font>]
    if newln [print newline]
]

; bold text
fbold: func [txt /newln][
    REPLPAD-WRITE/HTML unspaced [<i> txt </i>]
    if newln [print newline]
]

main: adapt 'console [
    !! {Start power calculations}
    replpad-reset
    GSTexc: func [num][
      round/to num / GST $0.01
    ]
    GSTinc: func [num][
      round/to num * 1.15 $0.01
    ]
    replpad-write/note/html spaced [
      {This utility calculates what your power bill might be with different providers based on information you provide.  It does need a power bill showing the number of days, and the units charged.}
      {Only a couple of providers are included initially.}
   ]
   ;JS-TRACE ON
   ;fbold/newln "this should be underlined!"
   
   forever [
       prin "Enable JS tracing? (y/n) "
       [JS-TRACE ON ("y" = input)]
       print newline
       prin "Enter whole days covered by this bill (Q): "
       days: input
       if days = "Q" [quit]
       if attempt [days: to-integer days][
           if zero? days [break]
           prin "Enter kWh used over this bill: "
           kWh: input 
           if attempt [kwH: to decimal! kwH][
               print "Enter kWh exported to the Grid over this period."  
               prin "Enter 0 or return if you don't have solar panels! "
               ep: 0
               attempt [ep: to decimal! input]
               ; got valid days and kWh so now calculate various scenarios
               
               ;;== 1. EnergyClub
               fred/newln "EnergyClub - standard user"
               fbold/newln "Fixed Costs"
               GST: 1 ; all rates are GST inclusive
               metering-per-day: $0.302466
               network-per-day: $1.265
               industry-per-day: $0.008489
               energy-pkwh: $0.090045
               solar-pkwh: $0.092
               network-uncontrolled-per-kwh: $0.083375
               electricity-authority-levy-per-kwh: $0.001265

               print spaced ["Meter charges" meter-charges: days * metering-per-day]
               print spaced ["Network Line Charges" network-charges: network-per-day * days]
               print spaced ["Industry Levies" industry-charges: industry-per-day * days]

               fbold/newln "Variable Charges"
               print spaced ["Energy Supply Costs:" energy-costs: energy-pkwh * kWh]
               print spaced ["Solar Rebate:" solar-rebate: negate solar-pkwh * ep]
               print spaced ["Network Line Charges (Uncontrolled):" network-line-costs: kwH * network-uncontrolled-per-kwh]
               print spaced ["Electrical Authority Levy:" network-levy-costs: electricity-authority-levy-per-kwh * kWh]
               print spaced ["Club Fee:" club: $5 * round/ceiling (days / 7)]
               print ["Total Energy Charges: " total: meter-charges + network-charges + industry-charges
               + energy-costs + network-line-costs + network-levy-costs]
               print ["Total inc GST" total-incgst: total * GST]
               print ["Total inc club fees" total-incgst-inc-club: GST * (total + club)]
               print ["Total less solar rebate:" round/to total-incgst-inc-club + solar-rebate $.01]
               print newline 
               ;;== Mercury Energy Low user
               GST: 1.15
               energy-pkwh: $0.21 
               solar-pkwh: $0.08
               daily-fixed-charge: $2.2465
               electricity-authority-levy-per-kwh: $0.001265
               fred/newln "Mercury low user"
               print spaced ["Standard - Anytime per kWh:" energy-pkwh]
               print spaced ["Daily Fixed charge:" daily-fixed-charge]
               energy-costs: GSTinc energy-pkwh * kWh
               print spaced ["Energy Supply Costs:" energy-costs "(" (GSTexc energy-costs) ")" ]

               print spaced ["Solar Rebate:" solar-rebate: negate solar-pkwh * ep]
               print spaced ["Daily fixed charges:" daily-fixed: GSTinc daily-fixed-charge * days "(" GSTexc daily-fixed ")" ]
               print spaced ["Electrical Authority Levy:" network-levy-costs: GSTinc electricity-authority-levy-per-kwh * kWh "(" GSTexc network-levy-costs ")"]
               
               print ["Total inc GST" total-incgst: round/to network-levy-costs + energy-costs + daily-fixed + solar-rebate $0.01]
               print newline 
               ;;== Mercury Standard user
               energy-pkwh: $0.2722
               solar-pkwh: $0.08
               daily-fixed-charge: $0.3333
               electricity-authority-levy-per-kwh: $0.001265
               fred/newln "Mercury Everyday User"
               print spaced ["Standard - Anytime per kWh:" energy-pkwh]
               print spaced ["Daily Fixed charge:" daily-fixed-charge]
               energy-costs: GSTinc energy-pkwh * kWh
               print spaced ["Energy Supply Costs:" energy-costs "(" (GSTexc energy-costs) ")" ]

               print spaced ["Solar Rebate:" solar-rebate: negate solar-pkwh * ep]
               print spaced ["Daily fixed charges:" daily-fixed: GSTinc daily-fixed-charge * days "(" GSTexc daily-fixed ")" ]
               print spaced ["Electrical Authority Levy:" network-levy-costs: GSTinc electricity-authority-levy-per-kwh * kWh "(" GSTexc network-levy-costs ")"]
               
               print ["Total inc GST" total-incgst: round/to network-levy-costs + energy-costs + daily-fixed + solar-rebate $0.01]
               print newline 
               fred/newln "Start New Calculation" 
           
           ] else [
               print "A valid number if required for power consumption"
           ]        
       ] else [print "Needs integer value for days of power bill"]
   ]
   main ; if break, restart the loop
]

; Having QUIT exit the interpreter can be useful in some debug builds which
; check various balances of state.
; https://github.com/hostilefork/replpad-js/issues/17
;
hijack 'quit adapt copy :quit [
    replpad-write/note/html spaced [
        {<b><i>Sorry to see you go...</i></b>}

        {<a href=".">click to restart interpreter</a>}
    ]

    ; Fall through to normal QUIT handling
]
