export interface OhosHttpFfiModule {
  setRequestState(headersJson: string, serverUrlsJson: string, token: string): number;
  setClientCertificate(certPath: string, keyPath: string, certType: string, keyPassword: string): number;
  clearClientCertificate(): number;
}

declare const ohosHttpFfiModule: OhosHttpFfiModule;

export default ohosHttpFfiModule;