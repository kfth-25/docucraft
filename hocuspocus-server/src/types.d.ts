declare module 'sql.js' {
  export interface Database {
    run(sql: string): any;
    prepare(sql: string): Statement;
    exec(sql: string): any;
    export(): Uint8Array;
    close(): void;
  }

  export interface Statement {
    run(...params: any[]): any;
    get(...params: any[]): any;
    all(...params: any[]): any[];
    iterate(...params: any[]): Iterator<any>;
  }

  export function initSqlJs(config?: { locateFile?: (file: string) => string }): Promise<{
    Database: new (data?: Uint8Array | ArrayBuffer | Buffer) => Database;
  }>;
}

declare module 'sql.js/wasm' {
  export default any;
}