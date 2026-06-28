/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

// Script for compiling build behavior. It is built in the build plug-in and cannot be modified currently.
import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import type { HvigorNode, HvigorPlugin } from '@ohos/hvigor';
import { execFileSync } from 'child_process';
import * as path from 'path';

const stageOhosHttpPluginLibs: HvigorPlugin = {
    pluginId: 'stage-ohos-http-plugin-libs',
    apply(node: HvigorNode): void {
        node.registerTask({
            name: 'stageOhosHttpPluginLibs',
            postDependencies: ['assembleHap'],
            run(taskContext): void {
                const scriptPath = path.resolve(
                    taskContext.modulePath,
                    '..',
                    '..',
                    'scripts',
                    'stage_ohos_http_plugin_libs.ps1',
                );
                execFileSync(
                    'powershell',
                    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath, '-BuildNative', '-FfiOnly'],
                    { stdio: 'inherit' },
                );
            },
        });
    },
};

export default {
    system: hapTasks,
    plugins: [stageOhosHttpPluginLibs],
};
