///////////////////////////////////////////////////////////////////////////////
// filename:    MasterServerUplink.uc
// version:     102
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// perpose:     replace the original masterserveruplink
///////////////////////////////////////////////////////////////////////////////

class MasterServerUplink extends IpDrv.MasterServerUplink config;

var config bool ListenToGamespy;
var config class<UdpGamespyQuery> UdpGamespyQueryClass;

event BeginPlay()
{
	local UdpGamespyQuery  GamespyQuery;
	local UdpGamespyUplink GamespyUplink;

  if ( ListenToGamespy )
  {
    log("Spawning ServQuery");
	  GamespyQuery  = Spawn(UdpGamespyQueryClass);
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
  UdpGamespyQueryClass=class'ServQuery'
}