import { common } from '@kit.AbilityKit'
import { ConnectivityApi, NetworkCapability } from './Connectivity.g'
import { connection } from '@kit.NetworkKit';
import { wifiManager } from '@kit.ConnectivityKit';

export class ConnectivityApiImpl extends ConnectivityApi {
  private ctx?: common.ApplicationContext;

  constructor(context: common.ApplicationContext) {
    super();
    this.ctx = context;
  }

  override getCapabilities(): Array<NetworkCapability> {
    let connectivityManager = connection.getDefaultNetSync();
    let netCapability = connection.getNetCapabilitiesSync(connectivityManager);
    let networkCap = netCapability.networkCap || [];
    let hasWifi = wifiManager.isConnected();
    let isWifiEnabled = wifiManager.isWifiActive();
    let hasCellular = networkCap.includes(connection.NetCap.NET_CAPABILITY_NOT_METERED)
    let hasVpn = !networkCap.includes(connection.NetCap.NET_CAPABILITY_NOT_VPN)
    let isUnmetered = !networkCap.includes(connection.NetCap.NET_CAPABILITY_NOT_METERED)

    let res = new Array<NetworkCapability>();
    if (hasWifi) {
      res.push(NetworkCapability.WIFI)
    }
    if (hasCellular) {
      res.push(NetworkCapability.CELLULAR)
    }
    if (hasVpn) {
      res.push(NetworkCapability.VPN);
      if (!hasWifi && !hasCellular) {
        if (isWifiEnabled) {
          res.push(NetworkCapability.WIFI)
        } else {
          res.push(NetworkCapability.CELLULAR)
        }
        // If VPN is active, but neither WIFI nor CELLULAR is reported as active,
        // assume CELLULAR if WIFI is not enabled
      }
    }

    return res;
  }
}


