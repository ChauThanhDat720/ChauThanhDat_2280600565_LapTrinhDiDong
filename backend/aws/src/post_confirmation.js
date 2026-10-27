import { CognitoIdentityProviderClient, AdminAddUserToGroupCommand } from '@aws-sdk/client-cognito-identity-provider';

export const createPostConfirmation = (client) => async (event) => {
  // ConfirmForgotPassword must not add a doctor/admin to the patient group.
  if (event.triggerSource === 'PostConfirmation_ConfirmSignUp') {
    await client.send(new AdminAddUserToGroupCommand({
      UserPoolId: event.userPoolId, Username: event.userName, GroupName: 'patients',
    }));
  }
  return event;
};
export const handler = createPostConfirmation(new CognitoIdentityProviderClient({}));
