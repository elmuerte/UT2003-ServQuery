///////////////////////////////////////////////////////////////////////////////
// filename:    MasterServerUplink.uc
// version:     101
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// perpose:     replace the original masterserveruplink
///////////////////////////////////////////////////////////////////////////////

class MasterServerUplink extends IpDrv.MasterServerUplink config;

var globalconfig bool ListenToGamespy;

event BeginPlay()
{
	local UdpGamespyQuery  GamespyQuery;
	local UdpGamespyUplink GamespyUplink;

  if ( ListenToGamespy )
  {
    log("Spawning ServQuery");
	  GamespyQuery  = Spawn( class'ServQuery' );
    // FMasterServerUplink needs this for NAT.
		GamespyQueryLink = GamespyQuery;
  }

  // if we're uplinking to gamespy, also spawn the gamespy actors.
	if( UplinkToGamespy )
	{
		GamespyUplink = Spawn( class'UdpGamespyUplink' );		
	}

	if( DoUplink )
	{
		// If we're sending stats, 
		if( SendStats )
		{
			foreach AllActors(class'MasterServerGameStats', GameStats )
			{
				if( GameStats.Uplink == None )
					GameStats.Uplink = Self;
				else
					GameStats = None;
				break;
			}		
			if( GameStats == None )
				Log("MasterServerUplink: MasterServerGameStats not found - stats uploading disabled.");
		}
	}

	Reconnect();
}

defaultproperties
{
  ListenToGamespy=true
}