///////////////////////////////////////////////////////////////////////////////
// filename:    ServQuery.uc
// version:     115
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// additional
//      ideas:  Ben Smit - ProAsm <proasm@stormnet.co.za>
// perpose:     adding team info to the GameSpyQuery
///////////////////////////////////////////////////////////////////////////////

class ServQuery extends UdpGameSpyQuery;

const VERSION = "115";

var config bool bVerbose;
var config string sReplyTo;
var config int iTimeframe;
var config int iProtectionType;
var config int iMaxQueryPerSecond; // type 1
var int iCurrentCount;
var config int iMaxQueryPerHostPerSecond; // type 2
var config string sPassword;

struct HostRecord
{
  var IpAddr Addr;
  var int count;
};
var array<HostRecord> HostRecords;

var int iHighestRequestCount; // for stats only

function PreBeginPlay()
{
  SetTimer(iTimeframe, true);
  Super.PreBeginPlay();
}

function int getHostDelay(IpAddr Addr)
{
  local int i;
  for (i = 0; i < HostRecords.length-1; i++)
  {
    if (HostRecords[i].Addr == Addr)
    {
      return ++HostRecords[i].count;
    }
  }
  HostRecords.Length = HostRecords.Length+1;
  HostRecords[i].Addr = Addr;
  return ++HostRecords[i].count;
}

event ReceivedText( IpAddr Addr, string Text )
{
  iCurrentCount++;
  if ((iProtectionType == 1) || (iProtectionType == -1))
  {    
    if (iCurrentCount > iMaxQueryPerSecond) 
    {
      if (bVerbose) Log("ServQuery: Query from"@IpAddrToString(addr)@"rejected (iMaxQueryPerSecond)");
      return;
    }
  }
  if ((iProtectionType == 2) || (iProtectionType == -1))
  {
    if (getHostDelay(addr) > iMaxQueryPerHostPerSecond) 
    {
      if (bVerbose) Log("ServQuery: Query from"@IpAddrToString(addr)@"rejected (iMaxQueryPerHostPerSecond)");
      return;
    }
  }
  Super.ReceivedText(addr, text);
}

event Timer()
{
  if (iCurrentCount > iHighestRequestCount) 
  {
    iHighestRequestCount = iCurrentCount;
    log("ServQuery: Highest Request Count Per Timeframe ("$iTimeframe@"sec):"@iHighestRequestCount);
  }
  iCurrentCount=0; // clear count every second;
  HostRecords.Length = 0;
}

function string ParseQuery( IpAddr Addr, coerce string Query, int QueryNum, out int PacketNum )
{
  local string QueryType, QueryValue, QueryRest;
	local bool Result;
  local int bFinalPacket;

  Result = ParseNextQuery(Query, QueryType, QueryValue, QueryRest, bFinalPacket);
	if( !Result )
		return "";

  if( QueryType=="teams" )
	{
    if (replayToQuery("T")) if (Level.Game.bTeamGame) Result = SendQueryPacket(Addr, GetTeams(), QueryNum, PacketNum, bFinalPacket);
	}
  else if( QueryType=="about" )
	{
		if (replayToQuery("A")) Result = SendQueryPacket(Addr, "\\about\\ServQuery "$VERSION$"\\author\\Michiel 'El Muerte' Hendriks\\authoremail\\elmuerte@drunksnipers.com\\HighestRequestCount\\"$string(iHighestRequestCount), QueryNum, PacketNum, bFinalPacket);
	}
  else if( QueryType=="spectators" )
	{
    if (replayToQuery("S")) Result = SendQueryPacket(Addr, GetSpectators(), QueryNum, PacketNum, bFinalPacket);
	}
  else if( QueryType=="gamestatus" )
	{
    if (replayToQuery("G")) Result = SendQueryPacket(Addr, GetGamestatus(), QueryNum, PacketNum, bFinalPacket);
	}
  else if( QueryType=="maplist" )
	{
    if (replayToQuery("M")) GetMaplist(Addr, QueryNum, PacketNum, bFinalPacket);
	}
  else if( QueryType=="echo" )
	{		
    if (replayToQuery("E")) 
    {
      ReplaceText(QueryValue, chr(10), ""); // fixed to remove the \n
	  	Result = SendQueryPacket(Addr, "\\echo_reply\\"$QueryValue, QueryNum, PacketNum, bFinalPacket);
    }
	}
  else if( QueryType=="bots" )
	{
    if (replayToQuery("B")) SendBots(Addr, QueryNum, PacketNum, bFinalPacket);
	}
  else if( QueryType==("playerhashes_"$sPassword) )
	{
    if (replayToQuery("H") && (sPassword != "")) SendPlayerHashes(Addr, QueryNum, PacketNum, bFinalPacket);
	}
  else super.ParseQuery(Addr, Query, QueryNum, PacketNum);
  return QueryRest;
}

function string GetTeam( TeamInfo T )
{
	local string ResultSet;

	// Name
	ResultSet = "\\team_"$T.TeamIndex$"\\"$T.GetHumanReadableName();
  //score
  ResultSet = ResultSet$"\\score_"$T.TeamIndex$"\\"$T.Score;
  //size
  ResultSet = ResultSet$"\\size_"$T.TeamIndex$"\\"$T.Size;

	return ResultSet;
}

function string GetTeams()
{
	local int i;
	local string Result;
	
	Result = "";
  for (i = 0; i < 2; i++)
  {
    Result = Result$GetTeam(TeamGame(Level.Game).Teams[i]);
  }
	return Result;
}

function string FixPlayerName(string name)
{
  local int i;
  i = InStr(name, "\\");
  while (i > -1)
  {
    name = Left(name, i)$Chr(127)$Mid(name, i+1);
    i = InStr(name, "\\");
  }
  return name;
}

function string GetPlayerDetails( Controller P, int PlayerNum )
{
  local string ResultSet;
  local int RealLives;

  // Frags
	ResultSet = "\\frags_"$PlayerNum$"\\"$int(P.PlayerReplicationInfo.Score);

	// Team
	if(P.PlayerReplicationInfo.Team != None)
		ResultSet = ResultSet$"\\team_"$PlayerNum$"\\"$P.PlayerReplicationInfo.Team.TeamIndex;
	else
		ResultSet = ResultSet$"\\team_"$PlayerNum$"\\0";

  // deaths
	ResultSet = ResultSet$"\\deaths_"$PlayerNum$"\\"$int(P.PlayerReplicationInfo.Deaths);

  // character
  ResultSet = ResultSet$"\\character_"$PlayerNum$"\\"$P.PlayerReplicationInfo.CharacterName;

  // scored
  ResultSet = ResultSet$"\\scored_"$PlayerNum$"\\"$P.PlayerReplicationInfo.GoalsScored;

  // has flag/ball ...
  ResultSet = ResultSet$"\\carries_"$PlayerNum$"\\"$(P.PlayerReplicationInfo.HasFlag != none);

  // number of lives
  // lives bug workaround
  RealLives = round(Level.Game.MaxLives - P.PlayerReplicationInfo.Deaths);
  if (RealLives < 0) RealLives = 0;
  ResultSet = ResultSet$"\\lives_"$PlayerNum$"\\"$RealLives;

  // time playing ...
  ResultSet = ResultSet$"\\playtime_"$PlayerNum$"\\"$int(Level.Game.StartTime-P.PlayerReplicationInfo.StartTime);

  return ResultSet;
}

// Return a string of information on a player.
function string GetPlayer( PlayerController P, int PlayerNum )
{
	local string ResultSet;

	// Name
	ResultSet = "\\player_"$PlayerNum$"\\"$FixPlayerName(P.PlayerReplicationInfo.PlayerName);

  // Ping
	ResultSet = ResultSet$"\\ping_"$PlayerNum$"\\"$P.ConsoleCommand("GETPING");

	return ResultSet$GetPlayerDetails(P, PlayerNum);
}

// Return a string of miscellaneous information.
// Game specific information, user defined data, custom parameters for the command line.
function string GetRules()
{
	local string ResultSet;
  local GameInfo.ServerResponseLine ServerState;
	local int i;
  local bool changedpass;

  changedpass = false;
	Level.Game.GetServerDetails( ServerState );
  for( i=0;i<ServerState.ServerInfo.Length;i++ )
  {
		if (ServerState.ServerInfo[i].Key ~= "password") {
      changedpass = true;
      ServerState.ServerInfo[i].Value = "1";
		}
  }
  if (changedpass == false) {
    i = ServerState.ServerInfo.Length;
    ServerState.ServerInfo.Length = i+1;
    ServerState.ServerInfo[i].Key = "password";
    ServerState.ServerInfo[i].Value = "0";
  }
	for( i=0;i<ServerState.ServerInfo.Length;i++ )
		ResultSet = ResultSet$"\\"$ServerState.ServerInfo[i].Key$"\\"$FixPlayerName(ServerState.ServerInfo[i].Value);
	return ResultSet;
}

// Return a string of information on a player.
function string GetSpectators()
{
  local string ResultSet;
	local Controller P;
  local int i;

  i = 0;
  for( P = Level.ControllerList; P != None; P = P.NextController )
  {
	  if (!P.bDeleteMe && P.bIsPlayer && P.PlayerReplicationInfo != None)
	  {
      if (P.PlayerReplicationInfo.bOnlySpectator)
      {
        // name
        ResultSet = ResultSet$"\\spectator_"$i$"\\"$FixPlayerName(P.PlayerReplicationInfo.PlayerName);
        // Ping
      	ResultSet = ResultSet$"\\specping_"$i$"\\"$P.ConsoleCommand("GETPING");
        i++;
      }
    }
  }
	return ResultSet;
}

// Return a string with game status information
function string GetGamestatus()
{
  local string ResultSet, CurrentMap;
  local MapList MyList;
  local int i;

  ResultSet = "\\elapsedtime\\"$Level.Game.GameReplicationInfo.ElapsedTime; // elapsed time of the game
  ResultSet = ResultSet$"\\timeseconds\\"$int(Level.TimeSeconds); // seconds the game is active
  ResultSet = ResultSet$"\\starttime\\"$int(Level.Game.StartTime); // time the game started at
  ResultSet = ResultSet$"\\overtime\\"$Level.Game.bOverTime;
  ResultSet = ResultSet$"\\gamewaiting\\"$Level.Game.bWaitingToStartMatch;
  MyList = Level.Game.GetMapList(Level.Game.MapListType);
  if (MyList != None)
	{
    CurrentMap = Left(string(Level), InStr(string(Level), "."));
  	if ( CurrentMap != "" )
  	{
  		for ( i=0; i < MyList.Maps.Length; i++ )
	  	{
		  	if ( CurrentMap ~= MyList.Maps[i] )
			  {
  				break;
	  		}
		  }
  	}
  	i++;
	  if ( i >= MyList.Maps.Length )
    {
      i = 0;
    }
    ResultSet = ResultSet$"\\nextmap\\"$FixPlayerName(MyList.Maps[i]);
		MyList.Destroy();
	}  
  return ResultSet;
}

function GetMaplist(IpAddr Addr, int QueryNum, out int PacketNum, int bFinalPacket)
{
  local MapList MyList;
  local int i;

  MyList = Level.Game.GetMapList(Level.Game.MapListType);
  if (MyList != None)
	{
    for ( i=0; i < MyList.Maps.Length; i++ )
	  {
      SendQueryPacket(Addr, "\\maplist_"$i$"\\"$FixPlayerName(MyList.Maps[i]), QueryNum, PacketNum, bFinalPacket);
    }
  }
}

// Return a string of information on a player.
function string GetBot( Controller P, int PlayerNum )
{
	local string ResultSet;

	// Name
	ResultSet = "\\bot_"$PlayerNum$"\\"$FixPlayerName(P.PlayerReplicationInfo.PlayerName);

  // Ping
	ResultSet = ResultSet$"\\ping_"$PlayerNum$"\\ "$P.PlayerReplicationInfo.Ping;

	return ResultSet$GetPlayerDetails(P, PlayerNum);
}

// Send data for each player
function bool SendBots(IpAddr Addr, int QueryNum, out int PacketNum, int bFinalPacket)
{
	local Controller P;
	local int i;
	local bool Result, SendResult;
	
	Result = false;

	i = 0;
  for( P = Level.ControllerList; P != None; P = P.NextController )
  {
	  if (!P.bDeleteMe && P.PlayerReplicationInfo != None)
	  {
      if (P.PlayerReplicationInfo.bBot)
      {		
  			SendResult = SendQueryPacket(Addr, GetBot(p, i), QueryNum, PacketNum, 0);
  			Result = SendResult || Result;
	  		i++;
		  }
    }
	}

	if(bFinalPacket==1)
  {
    SendResult = SendAPacket(Addr,QueryNum,PacketNum,bFinalPacket);
		Result = SendResult || Result;
	}

	return Result;
}

// get player hash information
function string GetPlayerHash( PlayerController P, int PlayerNum )
{
  local string ResultSet;

	ResultSet = "\\phname_"$PlayerNum$"\\"$FixPlayerName(P.PlayerReplicationInfo.PlayerName);
  ResultSet = ResultSet$"\\phash_"$PlayerNum$"\\"$P.GetPlayerIDHash();
  ResultSet = ResultSet$"\\phip_"$PlayerNum$"\\"$P.GetPlayerNetworkAddress();

  return ResultSet;
}

// Send data for each player
function bool SendPlayerHashes(IpAddr Addr, int QueryNum, out int PacketNum, int bFinalPacket)
{
	local Controller P;
	local int i;
	local bool Result, SendResult;
	
	Result = false;

	i = 0;
  for( P = Level.ControllerList; P != None; P = P.NextController )
  {
	  if (!P.bDeleteMe && P.bIsPlayer && (P.PlayerReplicationInfo != None) && !P.PlayerReplicationInfo.bBot)
	  {
  		SendResult = SendQueryPacket(Addr, GetPlayerHash(PlayerController(p), i), QueryNum, PacketNum, 0);
  		Result = SendResult || Result;
	  	i++;
    }
	}

	if(bFinalPacket==1)
  {
    SendResult = SendAPacket(Addr,QueryNum,PacketNum,bFinalPacket);
		Result = SendResult || Result;
	}

	return Result;
}

function bool replayToQuery(string type)
{
  return (InStr(sReplyTo, type) > -1);
}

defaultproperties
{
  sReplyTo="TASGMEBH";
  bVerbose=false
  iTimeframe=60
  iProtectionType=0  
  iMaxQueryPerSecond=180
  iMaxQueryPerHostPerSecond=10
}