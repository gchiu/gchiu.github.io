rebol [
    date: 16-Mar-2019
    author: "Graham Chiu"
    notes: {A function 'power to calculate rates from NZ power suppliers}
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
   
   forever [
       prin "Enable JS tracing? (y/n) "
       JS-TRACE ("y" = input)
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
