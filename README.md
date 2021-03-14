# UT2003-ServQuery

ServQuery is a fix for UT2003 servers. It fixes and extends the GameSpy Protocol. ServQuery will fix the backslash bug in the player names and ServQuery will add a new command to retreive Team information. Installing ServQuery will also enable server quering when you disable the master server uplink.

### New in version 101:

- more player details:
   - deaths_#    = times the player died
   - character_# = the character the player uses
   - scored_#    = times this player has scored for the team
   - carries_#   = has a flag/bombing ball

-    \rules\ command now displays more information like:
    gamespeed, servermode, gamestats, goalscore, timelimit, minplayers, translocator, mutator (pairs), password usage
    Actualy it will just send all the details the new UT2003 query will return.
-    new command: \spectators\
    this will return a list with spectators
-    new command: \gamestatus\
    returns some extra information about the game 

Thanks goes to: Ben Smit - ProAsm for a couple of these suggestions New in version 103:

- fixed a bug in the spectators list
- added a new property in the \gamestatus\ query: nextmap 

### New in version 104:

This version has been build to replace the MasterServerUplink. With a new option to enable GameSpy Protocol listning and disable GameSpy uplink. It's also independed from the DoUplink setting, so you can disable all uplink settings and still allow listning to the GameSpy Protocol. 

### New in version 105:

You can now set UplinkToGamespy independently to the DoUplink setting, if you set DoUplink to false and UplinkToGamespy to true it will only uplink to the GameSpy masterserver and not to the Epic Masterserver. 

### New in version 106:

Fixed a bug which caused the Map Cycle to be updated on a \gamestatus\ query 

### New in version 107:

- Fixed the next map, it displayed the wrong map every time
- Added the \maplist\ command to retreive the maplist 

### New in version 108:

- Fixes one security flaw
- Tries to fix another security flaw (http://www.pivx.com/kristovich/adv/mk001/)
- This fix implements a few new settings to limit the number of queries possible.
   - iProtectionType=0
   - iMaxQueryPerSecond=180
   - iMaxQueryPerHostPerSecond=10
   - The iProtectionType setting defines what form of protection to use:
      - 0: normal behavior
      - 1: limit the number of queries per second (iMaxQueryPerSecond)
      - 2: limit the number of queries per second per host (iMaxQueryPerHostPerSecond), this one is very slow and might have an impact on your server when you are being attacked
      - -1: use both 

### New in version 109:

You can specify the time frame (in seconds) the protection will use to check if the query exceeds the limit (iTimeframe)
- Max Requests Per Timeframe are now logged 

### New in version 110:

fixed the \maplist\ query, no all maps should be returned, not untill the buffer was full 

### New in version 111:

- changed the response of an \echo\ request to \echo_reply\ (security fix)
- fixed backslashes in mapnames and game info values
- added a new config variable to disable query types set sReplyTo to the types you want ServQuery to reply yo (only the non default replies can be disabled). By default sReplyTo=TASGME
   - T: \teams\
   - A: \about\
   - S: \spectators\
   - G: \gamestatus\
   - M: \maplist\
   - E: \echo\ (fixed version) 

### New in version 112:

- added \lives_#\ to the player details
- added support for \bots\ query to return bot details user B in sReplyTo to enable this feature \bots\ returns the same information as \players\ except that the first field is \bots_#\name (where # is the followup number) 

### New in version 113:

- fixed the \lives_#\ value
- added a new admin command: \playerhashes_<password>\ Where <password> is the value of config variable: sPassword sPassword has to be defined and sReplyTo has to contain H in order for this command to work. This command will return the followinf info for all players:
\phname_#\player name\phash_#\cdkey hash\phip_#\player ip 

### New in version 114:

- bug fixes 

### New in version 115:

- added ping to bots
- added \playtime_#\ to bots and players 

# Installation

Copy the ServQuery.u file to the UT2003 System directory. Then edit you UT2003 Server Configuration file (UT2003.ini) and add the following line:

```
    [Engine.GameEngine]
    ServerActors=ServQuery.MasterServerUplink
```

And remove the line:

```
    ServerActors=IpDrv.MasterServerUplink
```

Also remove the following line:

```
    ServerActors=ServQuery.ServQuery
```

You can disable listning to the GameSpy Protocol by setting the following in you configurations:

```
    [ServQuery.MasterServerUplink]
    ListenToGamespy=false
```

To turn off the uplink to the GameSpy master server add the line:

```
    UplinkToGamespy=false
```

From version 108 ServQuery provides a few security settings, you can tweak them with the following settings

```
    [ServQuery.ServQuery]
    iTimeframe=60
    iProtectionType=0
    iMaxQueryPerSecond=180
    iMaxQueryPerHostPerSecond=10
```

iProtectionType controlls what security measures should be used:

- 0: none
- 1: Limit max queries per time frame (iMaxQueryPerSecond)
- 2: Limit max queries per host per time frame (iMaxQueryPerHostPerSecond)
- -1: Use 1 and 2 together 

iTimeframe is the time frame, in seconds, the protection will look in. You should tweak around with these setting so that you will get the right value for your server.

Note: these security measures will not protect you for attacks, they will only make sure that you server is not used for DoS attacks.

# Usage
To get team information from the server just send:

```
    \teams\ 
```

to the GameSpy Protocol query port. You will then get the following information:

```
    \team_#\team name\score_#\team score\size_#\team size
```

Where # is the team number (0 or 1 since there are only 2 teams in UT2003) When you send a \status\ query to the server you will also get the team information.

To get a list of spectators send the following query:

```
    \spectators\
```

to the GameSpy Protocol query port. You will then get the following information:

```
    \spectator_#\name\specping_#\ping time
```

Where # a number.

To get extra game information send the following query:

```
    \gamestatus\
```

to the GameSpy Protocol query port. You will then get the following information (formatted in the GameSpy Protocol format):

- elapsedtime : seconds the game is running
- timeseconds : seconds this level has been loaded
- starttime   : seconds after `timeseconds` the game has started
- overtime    : if True playing in overtime
- gamewaiting : waiting for players

When retreiving player names the backslashes ('\') will replaced by ASCII char 127, this way you can still reconstruct the backslashes in the names.

To check if a server has this update installed you can send the query:

```
    \about\
```

SOME THINGS NOT EVERYBODY KNOWS:

* You can combine queries (also works with the default option):

```
    \basic\\players\\teams\\players\
```

* When the last command is an unknown command for UT2003 nothing will be returned, so if you send:

```
    \basic\\foo\
```

You won't receive anything. Keep this in mind when you use the extentions provided with ServQuery. Always let the last command be a known command, so for example:

```
    \spectators\\teams\\gamestats\\echo\something
```

Adding a \echo\something command to the end is a nice solution. 
