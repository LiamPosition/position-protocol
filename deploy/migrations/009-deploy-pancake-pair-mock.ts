import {MigrationContext, MigrationDefinition} from "../types";

const migrations: MigrationDefinition = {
    getTasks: (context: MigrationContext) => {
        return {
            'deploy Pancake Pair mock': async () => {
                await context.factory.createPancakePairMock();
            }
        }
    }
}

export default migrations