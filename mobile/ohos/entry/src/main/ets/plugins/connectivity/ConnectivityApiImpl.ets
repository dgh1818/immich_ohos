import { common } from '@kit.AbilityKit'
import { ConnectivityApi, NetworkCapability, NetworkCapabilityEnum } from './Connectivity.g'
import { connection } from '@kit.NetworkKit';
import { wifiManager } from '@kit.ConnectivityKit';

export class ConnectivityApiImpl extends ConnectivityApi {
  private ctx?: common.ApplicationContext;

  constructor(context: common.ApplicationContext) {
    super();
    this.ctx = context;
  }

  private wrapCapability(capability: NetworkCapability): NetworkCapabilityEnum {
    return new NetworkCapabilityEnum(NetworkCapability[capability] as string);
  }

  override getCapabilities(): Array<NetworkCapability> {
    let connectivityManager = connection.getDefaultNetSync();
    let netCapability = connection.getNetCapabilitiesSync(connectivityManager);
    let networkCap = netCapability.networkCap || [];
    let hasWifi = wifiManager.isConnected();
    let isWifiEnabled = wifiManager.isWifiActive();
    let hasCellular = networkCap.includes(connection.NetCap.NET_CAPABILITY_NOT_METERED)
    let hasVpn = !networkCap.includes(connection.NetCap.NET_CAPABILITY_NOT_VPN)
    let isUnmetered = hasWifi || networkCap.includes(connection.NetCap.NET_CAPABILITY_NOT_METERED)

    let res: Array<NetworkCapability | NetworkCapabilityEnum> = [];
    if (hasWifi) {
      res.push(this.wrapCapability(NetworkCapability.WIFI))
    }
    if (hasCellular) {
      res.push(this.wrapCapability(NetworkCapability.CELLULAR))
    }
    if (hasVpn) {
      res.push(this.wrapCapability(NetworkCapability.VPN));
      if (!hasWifi && !hasCellular) {
        if (isWifiEnabled) {
          res.push(this.wrapCapability(NetworkCapability.WIFI))
        } else {
          res.push(this.wrapCapability(NetworkCapability.CELLULAR))
        }
        // If VPN is active, but neither WIFI nor CELLULAR is reported as active,
        // assume CELLULAR if WIFI is not enabled
      }
    }
    if (isUnmetered) {
      res.push(this.wrapCapability(NetworkCapability.UNMETERED))
    }

    return res as Array<NetworkCapability>;
  }
}

