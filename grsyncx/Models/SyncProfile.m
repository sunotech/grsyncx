//
//  SyncProfile.m
//  grsyncx
//
//  Created by Michi on 24/04/2020.
//  Copyright © 2020 Michal Zelinka. All rights reserved.
//

#import "SyncProfile.h"
#import "UNXParsable.h"
#import "Foundation.h"

// Process receives an argument array directly, so shell quote characters must
// be interpreted here instead of being passed literally to openrsync.
static NSArray<NSString *> *GRSParseCommandLineArguments(NSString *string)
{
	if (!string.length) return @[];

	NSMutableArray<NSString *> *arguments = [NSMutableArray array];
	NSMutableString *argument = [NSMutableString string];
	NSCharacterSet *whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
	unichar quote = 0;
	BOOL escaping = NO;
	BOOL argumentStarted = NO;

	for (NSUInteger index = 0; index < string.length; index++)
	{
		unichar character = [string characterAtIndex:index];

		if (escaping)
		{
			[argument appendFormat:@"%C", character];
			escaping = NO;
			argumentStarted = YES;
			continue;
		}

		if (character == '\\' && quote != '\'')
		{
			escaping = YES;
			argumentStarted = YES;
			continue;
		}

		if (quote)
		{
			if (character == quote)
				quote = 0;
			else
				[argument appendFormat:@"%C", character];
			continue;
		}

		if (character == '\'' || character == '"')
		{
			quote = character;
			argumentStarted = YES;
		}
		else if ([whitespace characterIsMember:character])
		{
			if (argumentStarted)
			{
				[arguments addObject:[argument copy]];
				[argument setString:@""];
				argumentStarted = NO;
			}
		}
		else
		{
			[argument appendFormat:@"%C", character];
			argumentStarted = YES;
		}
	}

	if (escaping)
		[argument appendString:@"\\"];

	if (argumentStarted)
		[arguments addObject:[argument copy]];

	return [arguments copy];
}

@implementation SyncProfile

#pragma mark - Initializers

+ (instancetype)defaultProfile
{
	SyncProfile *def = [SyncProfile new];

	def.sourcePath = @"~";
	def.wrapInSourceFolder = YES;

	def.basicProperties =
		RSyncBasicPropPreserveTime | RSyncBasicPropPreservePermissions |
		RSyncBasicPropPreserveOwner | RSyncBasicPropPreserveGroup |
		RSyncBasicPropPreserveExtAttrs | RSyncBasicPropDeleteOnDest |
		RSyncBasicPropVerbose | RSyncBasicPropShowTransProgress;

	def.advancedProperties =
		RSyncAdvancedPropPreserveSymlinks | RSyncAdvancedPropShowItemizedChanges;

	return def;
}

- (instancetype)initFromDictionary:(NSDictionary *)dict
{
	NSString *name = dict.unx_parsable[@"Name"].string;

	if (!name) return nil;

	if (self = [super init])
	{
		_name = name;
		_sourcePath = dict.unx_parsable[@"Source"].string;
		_destinationPath = dict.unx_parsable[@"Destination"].string;
		_wrapInSourceFolder = dict.unx_parsable[@"WrapInSrcFolder"].number.boolValue;
		_basicProperties = dict.unx_parsable[@"BasicProps"].number.unsignedIntegerValue;
		_advancedProperties = dict.unx_parsable[@"AdvProps"].number.unsignedIntegerValue &
			~RSyncAdvancedPropProtectRemoteArgs;
		_additionalOptions = dict.unx_parsable[@"CustomOpts"].string;
	}

	return self;
}

- (NSDictionary *)asDictionary
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:8];

	dict[@"Name"] = self.name;

	id obj = _sourcePath;
	if (obj) dict[@"Source"] = obj;

	obj = _destinationPath;
	if (obj) dict[@"Destination"] = obj;

	dict[@"WrapInSrcFolder"] = @(_wrapInSourceFolder);

	dict[@"BasicProps"] = @(_basicProperties);
	dict[@"AdvProps"] = @(_advancedProperties & ~RSyncAdvancedPropProtectRemoteArgs);

	obj = _additionalOptions;
	if (obj) dict[@"CustomOpts"] = obj;

	return [dict copy];
}

#pragma mark - Getters

- (NSString *)name
{
	return _name ?: NSLocalizedString(@"default", @"Default sync profile name");
}

- (NSString *)calculatedSourcePath
{
	NSString *path = [_sourcePath copy];

	if (path && !_wrapInSourceFolder)
		path = [path stringByAppendingString:@"/"];

	return path;
}

- (NSString *)calculatedDestinationPath
{
	return [_destinationPath copy];
}

- (NSArray<NSString *> *)calculatedArguments
{
	NSMutableArray<NSString *> *args = [NSMutableArray arrayWithCapacity:32];

	#define HAS(x) ((x) > 0)

	RSyncBasicProp basic = _basicProperties;

	if (HAS(basic & RSyncBasicPropPreserveTime))           [args addObject:@"-t"];
	if (HAS(basic & RSyncBasicPropPreservePermissions))    [args addObject:@"-p"];
	if (HAS(basic & RSyncBasicPropPreserveOwner))          [args addObject:@"-o"];
	if (HAS(basic & RSyncBasicPropPreserveGroup))          [args addObject:@"-g"];
	// Apple openrsync currently reports metadata sidecar errors for -n -E.
	// Preserve extended attributes for real transfers, but omit -E for dry runs.
	if (HAS(basic & RSyncBasicPropPreserveExtAttrs) && !_simulatedRun)
		[args addObject:@"-E"];

	if (HAS(basic & RSyncBasicPropDeleteOnDest))           [args addObject:@"--delete"];
	if (HAS(basic & RSyncBasicPropDontLeaveFilesyst))      [args addObject:@"-x"];
	if (HAS(basic & RSyncBasicPropVerbose))                [args addObject:@"-v"];
	if (HAS(basic & RSyncBasicPropShowTransProgress))      [args addObject:@"--progress"];
	if (HAS(basic & RSyncBasicPropIgnoreExisting))         [args addObject:@"--ignore-existing"];
	if (HAS(basic & RSyncBasicPropSizeOnly))               [args addObject:@"--size-only"];
	if (HAS(basic & RSyncBasicPropSkipNewer))              [args addObject:@"--update"];
	if (HAS(basic & RSyncBasicPropWindowsCompat))          [args addObject:@"--modify-window=1"];

	RSyncAdvancedProp adv = _advancedProperties;

	if (HAS(adv & RSyncAdvancedPropAlwaysChecksum))        [args addObject:@"--checksum"];
	if (HAS(adv & RSyncAdvancedPropCompressFileData))      [args addObject:@"--compress"];
	if (HAS(adv & RSyncAdvancedPropPreserveDevices))       [args addObject:@"-D"];
	if (HAS(adv & RSyncAdvancedPropExistingFiles))         [args addObject:@"--existing"];
	if (HAS(adv & RSyncAdvancedPropPartialTransFiles))     [args addObject:@"-P"];
	if (HAS(adv & RSyncAdvancedPropNoUIDGIDMap))           [args addObject:@"--numeric-ids"];
	if (HAS(adv & RSyncAdvancedPropPreserveSymlinks))      [args addObject:@"-l"];
	if (HAS(adv & RSyncAdvancedPropPreserveHardLinks))     [args addObject:@"-H"];
	if (HAS(adv & RSyncAdvancedPropMakeBackups))           [args addObject:@"--backup"];
	if (HAS(adv & RSyncAdvancedPropShowItemizedChanges))   [args addObject:@"-i"];

	if (HAS(adv & RSyncAdvancedPropDisableRecursion))      [args addObject:@"-d"];
	else                                                   [args addObject:@"-r"];

	NSArray<NSString *> *additionalArgs = GRSParseCommandLineArguments(_additionalOptions);

	if (additionalArgs.count)
		[args addObjectsFromArray:additionalArgs];

	if (_simulatedRun)
		[args addObject:@"-n"];

	return [args copy];
}

@end
