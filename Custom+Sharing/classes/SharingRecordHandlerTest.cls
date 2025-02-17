@isTest
public class SharingRecordHandlerTest {
	
     @TestSetup
    private static void setup() {
        // Setup Test User
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        
        // Create a unique test user
        String uniqueId = 'test111@myorg1.com';
        User testUser = new User(
            Alias = 'test111', 
            Email = uniqueId, 
            EmailEncodingKey = 'UTF-8', 
            LastName = 'Testing', 
            LanguageLocaleKey = 'en_US', 
            LocaleSidKey = 'en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey = 'America/New_York', 
            UserName = uniqueId
        );
        insert testUser;

        // Assign Permission Set
        PermissionSet ps = [SELECT Id 
                            FROM PermissionSet 
                            WHERE Name = 'Sharing_Record_Permission'];
        insert new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = ps.Id);
    }
    
    @isTest
    static void testCreateLeadSharingRecord() {
        User testUser = [SELECT Id FROM User WHERE Username = 'test111@myorg1.com' LIMIT 1];
        
        Lead testLead = new Lead(LastName = 'Testc1', Company = 'Test Company11');
        insert testLead;
        System.runAs(testUser) {
            // Test: Successful sharing record creation for Lead
            Test.startTest();
            String result = SharingRecordHandler.createSharingRecord(testLead.Id, testUser.Id, 'Edit', Date.today().addDays(30));
            Test.stopTest();
            System.assertEquals('Success', result);

            // Verify sharing record for Lead
            LeadShare shareRecord = [SELECT Id, LeadAccessLevel, RowCause, UserOrGroupId FROM LeadShare WHERE LeadId = :testLead.Id AND UserOrGroupId = :testUser.Id LIMIT 1];
            System.assertEquals('Edit', shareRecord.LeadAccessLevel);
            System.assertEquals('Manual', shareRecord.RowCause);
            System.assertEquals(testUser.Id, shareRecord.UserOrGroupId);
        }
    }

    @isTest
    static void testCreateCustomObjectSharingRecord() {
        User testUser = [SELECT Id FROM User WHERE Username = 'test111@myorg1.com' LIMIT 1];
        
        Shared_Record__c testLead = new Shared_Record__c();
        insert testLead;
        System.runAs(testUser) {
            // Test: Successful sharing record creation for custom object
            Test.startTest();
            String result = SharingRecordHandler.createSharingRecord(testLead.Id, testUser.Id, 'Edit', Date.today().addDays(30));
            Test.stopTest();
            System.assertEquals('Success', result);

            // Verify sharing record for custom object
            Shared_Record__Share shareRecord = [SELECT Id, AccessLevel, RowCause, UserOrGroupId FROM Shared_Record__Share WHERE ParentId = :testLead.Id AND UserOrGroupId = :testUser.Id LIMIT 1];
            System.assertEquals('Edit', shareRecord.AccessLevel);
            System.assertEquals('Manual', shareRecord.RowCause);
            System.assertEquals(testUser.Id, shareRecord.UserOrGroupId);
        }
    }

    @isTest
    static void testCreateAccountSharingRecord() {
        // Create test user
        User testUser = [SELECT Id FROM User WHERE Username = 'test111@myorg1.com' LIMIT 1];
        
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        System.runAs(testUser) {
            try {
                // Test: Sharing record creation for Account should fail
                Test.startTest();
                String result = SharingRecordHandler.createSharingRecord(testAccount.Id, testUser.Id, 'Edit', Date.today().addDays(30));
                Test.stopTest();
                System.debug(result);
                System.assert(result.contains('Error'));

                // Verify no sharing record created for Account
                AccountShare shareRecord = [SELECT Id, AccountAccessLevel, RowCause, UserOrGroupId FROM AccountShare WHERE AccountId = :testAccount.Id AND UserOrGroupId = :testUser.Id LIMIT 1];
            } catch (Exception e) {
                System.debug('An unexpected error occurred: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void testPreventDuplicateLeadSharingRecords() {
        User testUser = [SELECT Id FROM User WHERE Username = 'test111@myorg1.com' LIMIT 1];
        
        // Create a Lead record
        Lead testLead = new Lead(LastName = 'Testc1', Company = 'Test Company11');
        insert testLead;

        System.runAs(testUser) {
            try {
                // Test: Prevent duplicate sharing records for the same Lead
                Test.startTest();
                String result1 = SharingRecordHandler.createSharingRecord(testLead.Id, testUser.Id, 'Edit', Date.today().addDays(30));
                String result2 = SharingRecordHandler.createSharingRecord(testLead.Id, testUser.Id, 'Edit', Date.today().addDays(30));
                Test.stopTest();
                System.assert(result1.contains('Success'));
                System.assert(!result2.contains('Success'));
            } catch (Exception e) {
                System.debug('An unexpected error occurred: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void testCreateAndDeleteLeadSharingRecords() {
        User testUser = [SELECT Id FROM User WHERE Username = 'test111@myorg1.com' LIMIT 1];
        
        // Create two Lead records with the same LastName and Company names
        Lead testLead1 = new Lead(LastName = 'Testc1', Company = 'Test Company11');
        insert testLead1;
        
        Lead testLead2 = new Lead(LastName = 'Testc1', Company = 'Test Company11');
        insert testLead2;

        System.runAs(testUser) {
            try {
                Test.startTest();
                // Create sharing records
                String result1 = SharingRecordHandler.createSharingRecord(testLead1.Id, testUser.Id, 'Edit', Date.today());
                String result2 = SharingRecordHandler.createSharingRecord(testLead2.Id, testUser.Id, 'Edit', Date.today().addDays(31));
                
                // Create an instance of DeleteSharedRecordSchedulable and call execute
                DeleteSharedRecordSchedulable deleteSchedulable = new DeleteSharedRecordSchedulable();
                deleteSchedulable.execute(null); // Mock the SchedulableContext parameter
                
                Test.stopTest();
                
                // Verify results
                System.assert(result1.contains('Success'));
                System.assert(result2.contains('Success'));
                
                List<LeadShare> shareRecords = [SELECT Id, LeadAccessLevel, RowCause, UserOrGroupId 
                                                FROM LeadShare
                                                WHERE LeadAccessLevel = 'Edit' AND RowCause = 'Manual'];
                
                System.debug('Share records: ' + shareRecords);
                
                // Ensure that the share records are not null or empty
                System.assert(!shareRecords.isEmpty(), 'Share records should exist for the test leads.');
                
                // Optional: Additional assertions on the retrieved records
                for (LeadShare shareRecord : shareRecords) {
                    System.assertEquals('Edit', shareRecord.LeadAccessLevel);
                    System.assertEquals('Manual', shareRecord.RowCause);
                    System.assertEquals(testUser.Id, shareRecord.UserOrGroupId);
                }
            } catch (Exception e) {
                System.debug('An unexpected error occurred: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void testCreateAndVerifyLeadSharingRecords() {
        User testUser = [SELECT Id FROM User WHERE Username = 'test111@myorg1.com' LIMIT 1];
        
        // Create two Lead records with the same LastName and Company names
        Lead testLead1 = new Lead(LastName = 'Testc11', Company = 'Test Company111');
        insert testLead1;
        
        Lead testLead2 = new Lead(LastName = 'Testc11', Company = 'Test Company111');
        insert testLead2;

        System.runAs(testUser) {
            try {
                Test.startTest();
                // Create sharing records
                String result1 = SharingRecordHandler.createSharingRecord(testLead1.Id, testUser.Id, 'Edit', Date.today().addDays(31));
                String result2 = SharingRecordHandler.createSharingRecord(testLead2.Id, testUser.Id, 'Edit', Date.today().addDays(32));
                
                // Create an instance of DeleteSharedRecordSchedulable and call execute
                DeleteSharedRecordSchedulable deleteSchedulable = new DeleteSharedRecordSchedulable();
                deleteSchedulable.execute(null); // Mock the SchedulableContext parameter
                
                Test.stopTest();
                
                // Verify results
                System.assert(result1.contains('Success'));
                System.assert(result2.contains('Success'));
                
                // Retrieve all LeadShare records related to the test leads
                List<LeadShare> shareRecords = [SELECT Id, LeadAccessLevel, RowCause, UserOrGroupId 
                                                FROM LeadShare
                                                WHERE LeadAccessLevel = 'Edit' AND RowCause = 'Manual'];
    
                System.debug('Share records: ' + shareRecords);
                
                // Ensure that the share records are not null or empty
                System.assert(!shareRecords.isEmpty(), 'Share records should exist for the test leads.');
                
                // Optional: Additional assertions on the retrieved records
                for (LeadShare shareRecord : shareRecords) {
                    System.assertEquals('Edit', shareRecord.LeadAccessLevel);
                    System.assertEquals('Manual', shareRecord.RowCause);
                    System.assertEquals(testUser.Id, shareRecord.UserOrGroupId);
                }
            } catch (Exception e) {
                System.debug('An unexpected error occurred: ' + e.getMessage());
            }
        }
    }
}