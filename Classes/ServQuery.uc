///////////////////////////////////////////////////////////////////////////////
// filename:    ServQuery.uc
// version:     107
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// additional
//      ideas:  Ben Smit - ProAsm <proasm@stormnet.co.za>
// perpose:     adding team info to the GameSpyQuery
///////////////////////////////////////////////////////////////////////////////

class ServQuery extends UdpGameSpyQuery;

const VERSION = "107";

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
    if (Level.Game.bTeamGame) Result = SendQueryPacket(Addr, GetTeams(), QueryNum, PacketNum, bFinalPacket);
	}
  else if( QueryType=="about" )
	{
		Result = SendQueryPacket(Addr, "\\about\\ServQuery "$VERSION$"\\author\\Michiel 'El Muerte' Hendriks\\authoremail\\elmuerte@drunksnipers.com", QueryNum, PacketNum, bFinalPacket);
	}
  else if( QueryType=="spectators" )
	{
    Result = SendQueryPacket(Addr, GetSpectators(), QueryNum, PacketNum, bFinalPacket);
	}
  else if( QueryType=="gamestatus" )
	{
    Result = SendQueryPacket(Addr, GetGamestatus(), QueryNum, PacketNum, bFinalPacket);
	}
  else if( QueryType=="maplist" )
	{
    Result = SendQueryPacket(Addr, GetMaplist(), QueryNum, PacketNum, bFinalPacket);
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

// Return a string of information on a player.
function string GetPlayer( PlayerController P, int PlayerNum )
{
	local string ResultSet;

	// Name
	ResultSet = "\\player_"$PlayerNum$"\\"$FixPlayerName(P.PlayerReplicationInfo.PlayerName);

	// Frags
	ResultSet = ResultSet$"\\frags_"$PlayerNum$"\\"$int(P.PlayerReplicationInfo.Score);

	// Ping
	ResultSet = ResultSet$"\\ping_"$PlayerNum$"\\"$P.ConsoleCommand("GETPING");

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

	return ResultSet;
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
		ResultSet = ResultSet$"\\"$ServerState.ServerInfo[i].Key$"\\"$ServerState.ServerInfo[i].Value;
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
    ResultSet = ResultSet$"\\nextmap\\"$MyList.Maps[i];
		MyList.Destroy();
	}  
  return ResultSet;
}

function string GetMaplist()
{
  local string ResultSet;
  local MapList MyList;
  local int i;

  MyList = Level.Game.GetMapList(Level.Game.MapListType);
  if (MyList != None)
	{
    for ( i=0; i < MyList.Maps.Length; i++ )
	  {
      ResultSet = ResultSet$"\\maplist_"$i$"\\"$MyList.Maps[i];
    }
  }
  return ResultSet;
}