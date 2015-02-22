@import CoreLocation;
@import HealthKit;

#import <Keys/CortadoKeys.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

#import "UIViewController+ReactiveCocoa.h"

#import "AddConsumptionViewModel.h"
#import "AddConsumptionViewController.h"
#import "DataStore.h"
#import "Drink.h"
#import "DrinkConsumption.h"
#import "DrinkConsumptionSerializer.h"
#import "HealthKitManager.h"
#import "CoffeeShopNotification.h"
#import "FoursquareClient.h"
#import "FoursquareVenue.h"
#import "FTUEViewController.h"
#import "HistoryViewController.h"
#import "HistoryViewModel.h"
#import "LocationFetcher.h"
#import "PreferredDrinksViewController.h"
#import "PreferredDrinksViewModel.h"

#import "AppDelegate.h"



@interface AppDelegate ()

@property (nonatomic, strong) DataStore *dataStore;
@property (nonatomic, strong) LocationFetcher *fetcher;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    HealthKitManager *healthKitManager = [[HealthKitManager alloc] init];
    self.dataStore = [[DataStore alloc] initWithHealthKitManager:healthKitManager];

    CortadoKeys *keys = [[CortadoKeys alloc] init];

    FoursquareClient *client = [[FoursquareClient alloc] initWithClientID:keys.foursquareClientID
                                  clientSecret:keys.foursquareClientSecret];
    self.fetcher = [[LocationFetcher alloc] initWithFoursquareClient:client];

    // Background fetch
    [application setMinimumBackgroundFetchInterval: UIApplicationBackgroundFetchIntervalMinimum];

    [UIApplication.sharedApplication registerForRemoteNotifications];

    // History
    HistoryViewModel *historyVM = [[HistoryViewModel alloc] initWithDataStore:self.dataStore];
    HistoryViewController *historyVC = [[HistoryViewController alloc] initWithViewModel:historyVM];
    UINavigationController *historyNav = [[UINavigationController alloc] initWithRootViewController:historyVC];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = historyNav;
    [self.window makeKeyAndVisible];

    return YES;
}

#pragma mark - Processing

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler {

    DrinkConsumption *consumption = [DrinkConsumptionSerializer consumptionFromUserInfo:notification.userInfo identifier:identifier];

    if (consumption.isValid) {
        [[self.dataStore addDrink:consumption]
            subscribeCompleted:completionHandler];
    } else {
        UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
        if (nav.presentedViewController) {
            [nav dismissViewControllerAnimated:NO completion:nil];
        }
        [nav popToRootViewControllerAnimated:NO];

        AddConsumptionViewModel *addVM = [[AddConsumptionViewModel alloc] initWithConsumption:(DrinkConsumption *)consumption];
        AddConsumptionViewController *addVC = [[AddConsumptionViewController alloc] initWithViewModel:addVM];
        UINavigationController *addNav = [[UINavigationController alloc] initWithRootViewController:addVC];

        [nav presentViewController:addNav animated:NO completion:nil];
        [[addVM.completedSignal
            flattenMap:^RACStream *(DrinkConsumption *c) {
                return [self.dataStore addDrink:c];
            }] subscribeCompleted:^{
                [nav dismissViewControllerAnimated:YES completion:nil];
                completionHandler();
            }];
    }
}

#pragma mark -
// TODO: This shouldn't be the purview of the app delegate,
// but this will make debugging easy for now.
- (void)manuallyCheckCurrentLocation {
    [self.fetcher manuallyCheckCurrentLocation];
}

@end
