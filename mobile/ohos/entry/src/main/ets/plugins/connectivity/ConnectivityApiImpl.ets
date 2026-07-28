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
    const connectivityManager = connection.getDefaultNetSync();
    const netCapability = connection.getNetCapabilitiesSync(connectivityManager);
    const networkCap = netCapability.networkCap || [];
    const bearerTypes = netCapability.bearerTypes;
    const hasWifi = bearerTypes.includes(connection.NetBearType.BEARER_WIFI) || wifiManager.isConnected();
    const hasCellular = bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR);
    const hasVpn =
      bearerTypes.includes(connection.NetBearType.BEARER_VPN) ||
      !networkCap.includes(connection.NetCap.NET_CAPABILITY_NOT_VPN);
    const isUnmetered =
      !hasCellular && networkCap.includes(connection.NetCap.NET_CAPABILITY_NOT_METERED);

    const res: Array<NetworkCapability | NetworkCapabilityEnum> = [];
    if (hasWifi) {
      res.push(this.wrapCapability(NetworkCapability.WIFI))
    }
    if (hasCellular) {
      res.push(this.wrapCapability(NetworkCapability.CELLULAR))
    }
    if (hasVpn) {
      res.push(this.wrapCapability(NetworkCapability.VPN));
      if (!hasWifi && !hasCellular) {
        if (wifiManager.isWifiActive()) {
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
