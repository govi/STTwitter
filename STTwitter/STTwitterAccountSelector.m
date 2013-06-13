//
//  STTwitterAccountSelector.m
//  TwitterTest
//
//  Created by Govi on 30/04/2013.
//  Copyright (c) 2013 Genie-Connect. All rights reserved.
//

#import "STTwitterAccountSelector.h"

@implementation STTwitterAccountSelector

+(void) getCurrentAccount:(void(^)(ACAccount *account))selected cancelled:(void(^)(NSError *error))cancelled {
    STTwitterAccountSelector *s = [STTwitterAccountSelector sharedSelector];
    if(s.currentAccount && selected)
        selected(s.currentAccount);
    else
        [self selectAccount:selected cancelled:cancelled];
}

+(void)selectAccount:(void(^)(ACAccount *account))selected cancelled:(void(^)(NSError *error))cancelled {
    STTwitterAccountSelector *s = [STTwitterAccountSelector sharedSelector];
    [s onSelectPerform:selected];
    [s onCancelPerform:cancelled];
    [s handleAccounts];
}

+(STTwitterAccountSelector *)sharedSelector {
    static STTwitterAccountSelector *s = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s = [[STTwitterAccountSelector alloc] init];
    });
    return s;
}

-(STTwitterAccountConfigStatus)hasConfiguredAccounts {
    accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    if ([accountType accessGranted])
    {
        NSArray *arr = [accountStore accountsWithAccountType:accountType];
        return [arr count] > 0 ? STTwitterAccountConfigStatusSelected:STTwitterAccountConfigStatusNoAccounts;
    }
    return lastStatus;
}

-(void)requestAccess {
    accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    if (![accountType accessGranted])
    {
        [accountStore requestAccessToAccountsWithType:accountType withCompletionHandler:^(BOOL granted, NSError *error) {
            if(error.code == 6) {//there are no accounts to approve
                lastStatus = STTwitterAccountConfigStatusNoAccounts;
                [[NSNotificationCenter defaultCenter] postNotificationName:kSTTwitterRegCompleteNotification object:nil];
            }
        }];
    }
}

-(void) onSelectPerform:(void(^)(ACAccount *account))selected {
    onSelect = [selected copy];
}

-(void) onCancelPerform:(void(^)(NSError *error))cancelled {
    onCancel = [cancelled copy];
}

-(void)handleAccounts {
    accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    if ([accountType accessGranted])
    {
        // have access already
        [self _showListOfTwitterAccountsFromStore:accountStore];
    }
    else
    {
        // need access first
        [accountStore requestAccessToAccountsWithType:accountType withCompletionHandler:^(BOOL granted, NSError *error) {
            if (granted)
            {
                [self _showListOfTwitterAccountsFromStore:accountStore];
            }
            else
            {
                onCancel(error);
            }
        }];
    }
}

- (void)_showListOfTwitterAccountsFromStore:(ACAccountStore *)aStore
{
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    self.shownAccounts = [accountStore accountsWithAccountType:accountType];
#if TARGET_OS_IPHONE
    UIActionSheet *actions = [[UIActionSheet alloc] initWithTitle:@"Choose Account to Use" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    actions.tag = 2;
    
    NSString *string = [[NSUserDefaults standardUserDefaults] objectForKey:kLastSelectedTwitterUsername];
    ACAccount *selectedAccount = nil;
    for (ACAccount *oneAccount in _shownAccounts)
    {
        [actions addButtonWithTitle:oneAccount.username];
        if(string && [string isEqualToString:oneAccount.username])
            selectedAccount = oneAccount;
    }
    
    if(selectedAccount) {
        int selected = [_shownAccounts indexOfObject:selectedAccount];
        [self selectAccountAtIndex:selected];
    } else {
        if([_shownAccounts count] > 1) {
            [actions addButtonWithTitle:@"Cancel"];
            actions.cancelButtonIndex = [_shownAccounts count];
            [actions showInView: [UIApplication sharedApplication].keyWindow];
        } else {
            if([_shownAccounts count] > 0)
                [self selectAccountAtIndex:0];
            else {
                NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"There are no twitter accounts configured" };
                onCancel([NSError errorWithDomain:@"STTwitterAccountSelector" code:0 userInfo:userInfo]);
                onCancel = nil;
            }
        }
    }
#else
    if([_shownAccounts count] > 0)
        [self selectAccountAtIndex:0];
    else {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"There are no twitter accounts configured" };
        onCancel([NSError errorWithDomain:@"STTwitterAccountSelector" code:0 userInfo:userInfo]);
        onCancel = nil;
    }
#endif
}

-(void)selectAccountAtIndex:(int) index {
    if(onSelect) {
        self.currentAccount = [_shownAccounts objectAtIndex:index];
        [[NSUserDefaults standardUserDefaults] setObject:self.currentAccount.username forKey:kLastSelectedTwitterUsername];
        [[NSUserDefaults standardUserDefaults] synchronize];
        onSelect([_shownAccounts objectAtIndex:index]);
        onSelect = nil;
    }
}

-(void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if(buttonIndex != actionSheet.cancelButtonIndex)
    {
        [self selectAccountAtIndex:buttonIndex];
    }
    else
    {
        if(onCancel)
        {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"User failed to select a Twitter account." };
            onCancel([NSError errorWithDomain:@"STTwitterAccountSelector" code:0 userInfo:userInfo]);
            onCancel = nil;
        }
    }
}

@end
