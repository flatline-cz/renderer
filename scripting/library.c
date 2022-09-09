//
// Created by tumap on 9/1/22.
//

const char *forth_init_code =
        // system calls
        ": emit    0 sys ; "
        ": .       1 sys ; "
        ": tell    2 sys ; "
        ": quit    128 sys ; "
        ": sin     129 sys ; "
        ": include 130 sys ; "
        ": save    131 sys ; "

        // dictionary access. These are shortcuts through the primitive operations are !!, @@ and ,,
        ": !    0 !! ; "
        ": @    0 @@ ; "
        ": ,    0 ,, ; "
        ": #    0 ## ; "

        // compiler state
        ": [ 0 compiling ! ; immediate "
        ": ] 1 compiling ! ; "
        ": postpone 1 _postpone ! ; immediate "

        // some operators and shortcuts
        ": 1+ 1 + ; "
        ": 1- 1 - ; "
        ": over 1 pick ; "
        ": +!   dup @ rot + swap ! ; "
        ": inc  1 swap +! ; "
        ": dec  -1 swap +! ; "
        ": <    - <0 ; "
        ": >    swap < ; "
        ": <=   over over >r >r < r> r> = + ; "
        ": >=   swap <= ; "
        ": =0   0 = ; "
        ": not  =0 ; "
        ": !=   = not ; "
        ": cr   10 emit ; "
        ": br 32 emit ; "
        ": ..   dup . ; "
        ": here h @ ; "

        // memory management
        ": allot  h +!  ; "
        ": var : ' lit , here 5 allot here swap ! 5 allot postpone ; ; "
        ": const : ' lit , , postpone ; ; "

        // define periodic update system
        "var NOW "
        "0 NOW ! "

        // graphics primitives
        ": set_position ( tile x y -- ) 128 sys ; "
        ": show_screen ( root_tile_handle -- ) 129 sys ; "
        ": set_visibility ( tile visible -- ) 130 sys ; "
        ": set_color ( tile red green blue alpha -- ) 131 sys ; "

        ": idle ( time -- ) 20 / 128 % 2 swap 0 0 255 set_color ; "


        ;
